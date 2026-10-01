import Foundation
import CoreMedia
import QuartzCore
import Accelerate
import os.log

private let logger = Logger(subsystem: "com.antigravity.SiriEdge", category: "AudioEnergyAnalyzer")

/// Lightweight, real-time audio signal processor operating entirely on background audio thread.
/// Performs zero-allocation RMS calculations, adaptive noise-floor tracking, hysteresis audio detection,
/// and low/high-frequency energy isolation.
public final class AudioEnergyAnalyzer {
    public static let shared = AudioEnergyAnalyzer()
    
    private let beatDetector = BeatDetector()
    
    // Pre-allocated reusable buffer for extracting mono float samples (no per-frame heap allocations)
    private var sampleBufferPool: [Float] = Array(repeating: 0.0, count: 4096)
    
    // Smoothed energy registers
    private var smoothedLevel: Float = 0.0
    private var smoothedBass: Float = 0.0
    private var smoothedHigh: Float = 0.0
    
    // Adaptive noise floor & dynamic threshold
    private var adaptiveNoiseFloor: Float = 0.003
    
    // Hysteresis timing registers
    private var timeAboveActivation: Double = 0.0
    private var timeBelowDeactivation: Double = 0.0
    private var isAudioActiveState: Bool = false
    private var lastProcessTimestamp: Double = 0.0
    
    // Spectral filter states (1-pole IIR filters for zero CPU overhead)
    private var bassFilterState: Float = 0.0
    private var highFilterState: Float = 0.0
    
    public init() {
        self.lastProcessTimestamp = CACurrentMediaTime()
    }
    
    public var isAudioActive: Bool { isAudioActiveState }
    public var smoothedEnergy: Float { smoothedLevel }
    
    /// Processes incoming CMSampleBuffer on the background audio thread.
    public func process(sampleBuffer: CMSampleBuffer, reactivityMultiplier: Float, beatMultiplier: Float) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let totalByteLength = CMBlockBufferGetDataLength(blockBuffer)
        guard totalByteLength > 0 else { return }
        
        // Ensure pool capacity matches incoming buffer size without frequent reallocations
        let sampleCount = totalByteLength / MemoryLayout<Float>.size
        if sampleBufferPool.count < sampleCount {
            sampleBufferPool = Array(repeating: 0.0, count: max(sampleCount, 4096))
        }
        
        // Copy audio samples into contiguous buffer
        let status = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: totalByteLength, destination: &sampleBufferPool)
        guard status == kCMBlockBufferNoErr else { return }
        
        process(samples: sampleBufferPool, count: sampleCount, reactivityMultiplier: reactivityMultiplier, beatMultiplier: beatMultiplier)
    }
    
    /// Internal / testable processing method for float audio samples
    public func process(samples: [Float], count: Int, reactivityMultiplier: Float = 1.0, beatMultiplier: Float = 1.0) {
        let now = CACurrentMediaTime()
        let dt = (lastProcessTimestamp > 0.0) ? min(0.1, max(0.001, now - lastProcessTimestamp)) : 0.02
        lastProcessTimestamp = now
        let sampleCount = count
        
        // 1. SIMD-Accelerated RMS Energy Calculation via vDSP
        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(sampleCount))
        
        // 2. Adaptive Noise Floor Tracking
        if rms < adaptiveNoiseFloor {
            adaptiveNoiseFloor = adaptiveNoiseFloor * 0.95 + rms * 0.05
        } else {
            adaptiveNoiseFloor = adaptiveNoiseFloor * 0.999 + rms * 0.001
        }
        adaptiveNoiseFloor = max(0.001, min(0.025, adaptiveNoiseFloor))
        
        // Effective musical energy above noise floor
        let effectiveEnergy = max(0.0, rms - adaptiveNoiseFloor)
        
        // 3. Hysteresis Audio Activity Gate
        // Activation: Energy above 0.004 for > 60ms
        // Deactivation: Energy below 0.002 for > 700ms of continuous silence
        let activationThreshold: Float = 0.004
        let deactivationThreshold: Float = 0.002
        
        if effectiveEnergy > activationThreshold {
            timeAboveActivation += dt
            timeBelowDeactivation = 0.0
            if timeAboveActivation >= 0.060 {
                isAudioActiveState = true
            }
        } else if effectiveEnergy < deactivationThreshold {
            timeBelowDeactivation += dt
            timeAboveActivation = 0.0
            if timeBelowDeactivation >= 0.700 {
                isAudioActiveState = false
            }
        } else {
            // In hysteresis deadband, maintain current state
            timeAboveActivation = 0.0
            timeBelowDeactivation = 0.0
        }
        
        // 4. Low-Frequency (Bass) and High-Frequency Isolation via 1-pole filter
        var bassSum: Float = 0.0
        var highSum: Float = 0.0
        let strideLen = max(1, sampleCount / 256) // Decimate for ultra-low CPU
        var decimatedCount = 0
        
        for i in stride(from: 0, to: sampleCount, by: strideLen) {
            let s = samples[i]
            // Low-pass filter (~200Hz at 16kHz)
            bassFilterState = bassFilterState * 0.85 + s * 0.15
            bassSum += abs(bassFilterState)
            
            // High-pass filter (~3kHz at 16kHz)
            let high = s - bassFilterState
            highSum += abs(high)
            decimatedCount += 1
        }
        
        let avgBass = decimatedCount > 0 ? (bassSum / Float(decimatedCount)) : 0.0
        let avgHigh = decimatedCount > 0 ? (highSum / Float(decimatedCount)) : 0.0
        
        // 5. Attack / Release Smoothing
        let normalizedLevel = min(1.0, effectiveEnergy * 25.0 * reactivityMultiplier)
        let normalizedBass = min(1.0, max(0.0, avgBass - adaptiveNoiseFloor) * 35.0 * reactivityMultiplier)
        let normalizedHigh = min(1.0, max(0.0, avgHigh - adaptiveNoiseFloor) * 30.0 * reactivityMultiplier)
        
        // Fast attack (~15ms), smooth release (~80ms)
        let attackAlpha: Float = 0.35
        let releaseAlpha: Float = 0.10
        
        let levelAlpha = (normalizedLevel > smoothedLevel) ? attackAlpha : releaseAlpha
        smoothedLevel = smoothedLevel * (1.0 - levelAlpha) + normalizedLevel * levelAlpha
        
        let bassAlpha = (normalizedBass > smoothedBass) ? attackAlpha : releaseAlpha
        smoothedBass = smoothedBass * (1.0 - bassAlpha) + normalizedBass * bassAlpha
        
        let highAlpha = (normalizedHigh > smoothedHigh) ? attackAlpha : releaseAlpha
        smoothedHigh = smoothedHigh * (1.0 - highAlpha) + normalizedHigh * highAlpha
        
        // 6. Beat and Transient Detection
        let beatPulse = beatDetector.process(
            frameEnergy: effectiveEnergy,
            noiseFloor: adaptiveNoiseFloor,
            sensitivity: beatMultiplier
        )
        
        // 7. Update Thread-Safe Shared State for Metal Renderer
        MusicReactiveState.shared.update(
            audioLevel: isAudioActiveState ? smoothedLevel : 0.0,
            beatPulse: isAudioActiveState ? beatPulse : 0.0,
            bassLevel: isAudioActiveState ? smoothedBass : 0.0,
            highLevel: isAudioActiveState ? smoothedHigh : 0.0,
            isAudioActive: isAudioActiveState
        )
    }
    
    /// Clears filter registers on stream stop
    public func reset() {
        smoothedLevel = 0.0
        smoothedBass = 0.0
        smoothedHigh = 0.0
        timeAboveActivation = 0.0
        timeBelowDeactivation = 0.0
        isAudioActiveState = false
        beatDetector.reset()
        MusicReactiveState.shared.reset()
    }
}
