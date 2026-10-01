import Foundation
import QuartzCore

/// Local real-time transient and beat detector.
/// Uses dynamic energy variance, adaptive thresholds, minimum beat refractory period,
/// and smooth exponential decay to produce organic, Apple-like beat responses without strobing.
public final class BeatDetector {
    // Configurable refractory period (~140ms = max ~428 BPM, preventing rapid strobing/double hits)
    private let minBeatInterval: CFTimeInterval = 0.140
    
    // Internal energy history & envelope
    private var energyHistory: [Float] = Array(repeating: 0.005, count: 16)
    private var historyIndex: Int = 0
    private var smoothedAverageEnergy: Float = 0.005
    
    // State registers
    private var lastBeatTime: CFTimeInterval = 0.0
    private var currentBeatPulse: Float = 0.0
    private var lastProcessTime: CFTimeInterval = 0.0
    
    public init() {
        self.lastProcessTime = CACurrentMediaTime()
    }
    
    /// Processes incoming instantaneous frame energy and returns the current smoothed beat pulse [0.0 ... 1.0].
    /// - Parameters:
    ///   - frameEnergy: Instantaneous RMS energy of the current buffer.
    ///   - noiseFloor: Adaptive noise floor level.
    ///   - sensitivity: User sensitivity multiplier (0.5 for Low, 1.0 for Medium, 1.5 for High).
    public func process(frameEnergy: Float, noiseFloor: Float, sensitivity: Float) -> Float {
        let now = CACurrentMediaTime()
        let dt = Float(max(0.001, min(0.1, now - lastProcessTime)))
        lastProcessTime = now
        
        // 1. Exponential decay of active beat pulse
        // Decay half-life ~70ms produces an organic, silky fade back to normal music state
        let decayRate: Float = 14.0
        currentBeatPulse = max(0.0, currentBeatPulse * exp(-decayRate * dt))
        
        // 2. Ignore noise floor fluctuations
        let effectiveEnergy = max(0.0, frameEnergy - noiseFloor)
        if effectiveEnergy < 0.002 {
            return currentBeatPulse
        }
        
        // 3. Update rolling energy history
        energyHistory[historyIndex] = effectiveEnergy
        historyIndex = (historyIndex + 1) % energyHistory.count
        
        var sum: Float = 0.0
        for e in energyHistory { sum += e }
        let avgEnergy = sum / Float(energyHistory.count)
        
        // Smoothly adapt average energy
        smoothedAverageEnergy = smoothedAverageEnergy * 0.90 + avgEnergy * 0.10
        
        // 4. Compute energy variance to adjust detection threshold dynamically
        var varianceSum: Float = 0.0
        for e in energyHistory {
            let diff = e - avgEnergy
            varianceSum += diff * diff
        }
        let variance = varianceSum / Float(energyHistory.count)
        
        // Dynamic threshold: higher variance (percussive music) requires a sharper spike
        // Sensitivity shifts the threshold lower or higher
        let baseMultiplier: Float = 1.35 / max(0.2, sensitivity)
        let dynamicThreshold = smoothedAverageEnergy * baseMultiplier + sqrt(variance) * 0.5
        
        // 5. Transient detection with refractory gate
        let timeSinceLastBeat = now - lastBeatTime
        let isTransientSpike = effectiveEnergy > dynamicThreshold && effectiveEnergy > (smoothedAverageEnergy * 1.20)
        
        if isTransientSpike && timeSinceLastBeat >= minBeatInterval {
            // Transient beat detected!
            lastBeatTime = now
            
            // Calculate impulse strength proportional to spike ratio, clamped to [0.6 ... 1.0]
            let spikeRatio = min(2.0, effectiveEnergy / max(0.001, dynamicThreshold))
            let impulseStrength = min(1.0, max(0.60, Float(spikeRatio * 0.65)))
            
            // Apply impulse smoothly
            currentBeatPulse = max(currentBeatPulse, impulseStrength)
        }
        
        return currentBeatPulse
    }
    
    /// Resets beat state on silence or pause
    public func reset() {
        currentBeatPulse = 0.0
        lastBeatTime = 0.0
        energyHistory = Array(repeating: 0.005, count: 16)
        smoothedAverageEnergy = 0.005
    }
}
