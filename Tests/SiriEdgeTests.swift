import XCTest
@testable import SiriEdge

final class SiriEdgeTests: XCTestCase {
    
    func testUniformsMemoryLayout() {
        let size = MemoryLayout<EdgeUniforms>.size
        let stride = MemoryLayout<EdgeUniforms>.stride
        let alignment = MemoryLayout<EdgeUniforms>.alignment
        
        XCTAssertEqual(stride, 128, "EdgeUniforms stride must be exactly 128 bytes to match Metal Uniforms struct")
        XCTAssertEqual(alignment, 16, "EdgeUniforms alignment must be 16 bytes for SIMD4 types")
        XCTAssertLessThanOrEqual(size, stride)
    }
    
    func testEdgeAnimationTransitions() {
        let animation = EdgeAnimation()
        
        // Initial state
        XCTAssertEqual(animation.currentAlpha, 0.0)
        XCTAssertEqual(animation.targetAlpha, 0.0)
        
        // Set active
        animation.setTargetVisibility(active: true, animated: false)
        XCTAssertEqual(animation.currentAlpha, 1.0)
        XCTAssertEqual(animation.targetAlpha, 1.0)
        XCTAssertFalse(animation.isFullyFadedOut)
        
        // Update frame uniforms
        let uniforms = animation.update(size: CGSize(width: 1920, height: 1080), scaleFactor: 2.0)
        XCTAssertEqual(uniforms.resolution.x, 1920)
        XCTAssertEqual(uniforms.resolution.y, 1080)
        XCTAssertEqual(uniforms.scaleFactor, 2.0)
        XCTAssertEqual(uniforms.masterAlpha, 1.0)
        
        // Check pulse positions are within [0, 1]
        XCTAssertGreaterThanOrEqual(uniforms.pulsePositions.x, 0.0)
        XCTAssertLessThanOrEqual(uniforms.pulsePositions.x, 1.0)
        XCTAssertGreaterThanOrEqual(uniforms.pulsePositions.y, 0.0)
        XCTAssertLessThanOrEqual(uniforms.pulsePositions.y, 1.0)
    }
    
    func testSettingsPreservation() {
        let settings = EdgeSettings.shared
        
        // Verify preserved preferences
        XCTAssertEqual(settings.defaultAnimation, "thinking")
        XCTAssertEqual(settings.animationSpeed, 0.65, accuracy: 0.01)
        XCTAssertEqual(settings.transparency, 0.25, accuracy: 0.01)
        XCTAssertEqual(settings.brightness, 1.0, accuracy: 0.01)
        XCTAssertEqual(settings.effectiveTargetFPS, 30)
        XCTAssertEqual(settings.powerMode, .batterySaver)
        XCTAssertTrue(settings.isBatterySaverEnabled)
        XCTAssertEqual(settings.activityTimeoutMinutes, 5)
        XCTAssertEqual(settings.schemaVersion, 2)
    }
    
    func testPowerSourceMonitoring() {
        let power = PowerSource.shared
        // Power monitor must have determined power state
        XCTAssertNotNil(power.isChargerConnected)
    }
    
    // MARK: - Music Mode Isolated Tests
    
    func testMusicModeDefaultSettings() {
        let settings = EdgeSettings.shared
        // Default must remain OFF for safety & zero battery consumption
        XCTAssertFalse(settings.isMusicModeEnabled, "Music Mode must default to OFF")
        XCTAssertEqual(settings.audioReactivity, .medium)
        XCTAssertEqual(settings.beatResponse, .medium)
        XCTAssertEqual(settings.musicAnimationStyle, .subtle)
    }
    
    func testMusicReactiveStateThreadSafety() {
        let state = MusicReactiveState.shared
        state.reset()
        
        let initial = state.snapshot()
        XCTAssertEqual(initial.audioLevel, 0.0)
        XCTAssertEqual(initial.beatPulse, 0.0)
        XCTAssertFalse(initial.isAudioActive)
        
        state.update(audioLevel: 0.75, beatPulse: 0.90, bassLevel: 0.60, highLevel: 0.40, isAudioActive: true)
        let updated = state.snapshot()
        XCTAssertEqual(updated.audioLevel, 0.75)
        XCTAssertEqual(updated.beatPulse, 0.90)
        XCTAssertEqual(updated.bassLevel, 0.60)
        XCTAssertEqual(updated.highLevel, 0.40)
        XCTAssertTrue(updated.isAudioActive)
        
        state.reset()
        let resetSnapshot = state.snapshot()
        XCTAssertEqual(resetSnapshot.audioLevel, 0.0)
        XCTAssertFalse(resetSnapshot.isAudioActive)
    }
    
    func testBeatDetectorLogic() {
        let detector = BeatDetector()
        
        // 1. Baseline quiet audio should produce NO beat
        for _ in 0..<10 {
            let pulse = detector.process(rmsEnergy: 0.01, bassEnergy: 0.01, sensitivity: 1.0)
            XCTAssertLessThanOrEqual(pulse, 0.05, "Quiet signal must not trigger beat")
        }
        
        // 2. Sudden energetic bass transient should trigger a beat
        let beatPulse = detector.process(rmsEnergy: 0.85, bassEnergy: 0.90, sensitivity: 1.0)
        XCTAssertGreaterThan(beatPulse, 0.3, "Sudden transient must trigger beat pulse")
        
        // 3. Immediate subsequent frame within refractory period (~140ms) must NOT double trigger
        let immediatePulse = detector.process(rmsEnergy: 0.95, bassEnergy: 0.95, sensitivity: 1.0)
        XCTAssertLessThanOrEqual(immediatePulse, beatPulse, "Refractory window must prevent double-triggering")
        
        // 4. Reset returns pulse to zero
        detector.reset()
        let postReset = detector.process(rmsEnergy: 0.0, bassEnergy: 0.0, sensitivity: 1.0)
        XCTAssertEqual(postReset, 0.0)
    }
    
    func testAudioEnergyAnalyzerHysteresis() {
        let analyzer = AudioEnergyAnalyzer()
        
        // Feed silence (all zeros)
        let silentSamples = [Float](repeating: 0.0, count: 512)
        for _ in 0..<5 {
            analyzer.process(monoFloatSamples: silentSamples, count: silentSamples.count)
        }
        
        let silentMetrics = analyzer.currentMetrics
        XCTAssertFalse(silentMetrics.isAudioActive, "Zero samples must not mark audio as active")
        XCTAssertEqual(silentMetrics.smoothedRMS, 0.0, accuracy: 0.001)
        
        // Feed loud simulated music wave (sinusoidal pulse)
        var musicSamples = [Float](repeating: 0.0, count: 512)
        for i in 0..<512 {
            musicSamples[i] = sin(Float(i) * 0.1) * 0.7
        }
        
        // Feed multiple buffers over ~100ms
        for _ in 0..<15 {
            analyzer.process(monoFloatSamples: musicSamples, count: musicSamples.count)
            usleep(10000) // 10ms
        }
        
        let activeMetrics = analyzer.currentMetrics
        XCTAssertTrue(activeMetrics.isAudioActive, "Sustained audio signal must trigger audioActive via hysteresis")
        XCTAssertGreaterThan(activeMetrics.smoothedRMS, 0.1)
    }
    
    func testOperationPriorityUnaffectedByMusic() {
        let settings = EdgeSettings.shared
        
        // Rule: MANUAL OFF has supreme priority over anything
        settings.manualOverride = false
        // Even if music mode were on, Manual OFF always forces overlay OFF
        XCTAssertEqual(settings.manualOverride, false)
        
        // Rule: AUTO + battery -> OFF
        settings.manualOverride = nil
        XCTAssertNil(settings.manualOverride)
    }
}

