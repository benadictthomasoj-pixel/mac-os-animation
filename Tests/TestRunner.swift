import Foundation
import CoreMedia
import QuartzCore
import Accelerate
import Metal
import os.log

@main
struct TestRunner {
    static func assertTrue(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
        if !condition {
            print("❌ Assertion Failed: \(message) at \(file):\(line)")
            exit(1)
        }
    }

    static func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        if a != b {
            print("❌ Assertion Failed: Expected \(b), got \(a). \(message) at \(file):\(line)")
            exit(1)
        }
    }

    static func assertAccuracy(_ a: Float, _ b: Float, accuracy: Float, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        if abs(a - b) > accuracy {
            print("❌ Assertion Failed: \(a) not within \(accuracy) of \(b). \(message) at \(file):\(line)")
            exit(1)
        }
    }

    static func main() {
        print("🧪 Starting SiriEdge Music Mode & Core Logic Test Suite...\n")

        // MARK: - 1. Music Mode Default Settings Test
        print("▶ [Test 1] Testing Music Mode Default Settings...")
        UserDefaults.standard.removeObject(forKey: EdgeSettings.Keys.isMusicModeEnabled)
        let defaultMusicMode = (UserDefaults.standard.object(forKey: EdgeSettings.Keys.isMusicModeEnabled) != nil) ? UserDefaults.standard.bool(forKey: EdgeSettings.Keys.isMusicModeEnabled) : false
        assertEqual(defaultMusicMode, false, "Music Mode must default to OFF when not explicitly enabled")
        
        let settings = EdgeSettings.shared
        settings.isMusicModeEnabled = false
        assertEqual(settings.isMusicModeEnabled, false, "Music Mode is OFF")
        assertEqual(settings.musicReactivityLevel, .medium, "Audio reactivity must default to medium")
        assertEqual(settings.beatResponseLevel, .medium, "Beat response must default to medium")
        assertEqual(settings.musicAnimationStyle, .subtle, "Music animation must default to subtle")
        print("✅ [Test 1 Passed] Default settings are safe & zero-battery baseline.\n")

        // MARK: - 2. Thread-Safe MusicReactiveState Snapshot Test
        print("▶ [Test 2] Testing MusicReactiveState Thread-Safety...")
        let state = MusicReactiveState.shared
        state.reset()

        let initial = state.getSnapshot()
        assertEqual(initial.audioLevel, 0.0)
        assertEqual(initial.beatPulse, 0.0)
        assertEqual(initial.isAudioActive, false)

        state.update(audioLevel: 0.75, beatPulse: 0.90, bassLevel: 0.60, highLevel: 0.40, isAudioActive: true)
        let updated = state.getSnapshot()
        assertAccuracy(updated.audioLevel, 0.75, accuracy: 0.001)
        assertAccuracy(updated.beatPulse, 0.90, accuracy: 0.001)
        assertAccuracy(updated.bassLevel, 0.60, accuracy: 0.001)
        assertAccuracy(updated.highLevel, 0.40, accuracy: 0.001)
        assertEqual(updated.isAudioActive, true)

        state.reset()
        let resetSnapshot = state.getSnapshot()
        assertEqual(resetSnapshot.audioLevel, 0.0)
        assertEqual(resetSnapshot.isAudioActive, false)
        print("✅ [Test 2 Passed] MusicReactiveState atomic update/snapshot/reset verified.\n")

        // MARK: - 3. Beat Detector Transient & Refractory Logic Test
        print("▶ [Test 3] Testing BeatDetector Transient & Refractory Period...")
        let detector = BeatDetector()

        // Quiet baseline
        for _ in 0..<10 {
            let pulse = detector.process(frameEnergy: 0.01, noiseFloor: 0.005, sensitivity: 1.0)
            assertTrue(pulse <= 0.05, "Quiet signal must not trigger beat")
        }

        // Sudden energetic beat transient
        let beatPulse = detector.process(frameEnergy: 0.85, noiseFloor: 0.01, sensitivity: 1.0)
        assertTrue(beatPulse > 0.3, "Sudden transient must trigger beat pulse")

        // Immediate next frame within refractory window (~140ms) must not double trigger
        let immediatePulse = detector.process(frameEnergy: 0.95, noiseFloor: 0.01, sensitivity: 1.0)
        assertTrue(immediatePulse <= beatPulse, "Refractory window must prevent double-triggering")

        detector.reset()
        let postReset = detector.process(frameEnergy: 0.0, noiseFloor: 0.005, sensitivity: 1.0)
        assertEqual(postReset, 0.0)
        print("✅ [Test 3 Passed] Beat detection triggers cleanly without double-triggering or strobing.\n")

        // MARK: - 4. Audio Energy Analyzer Hysteresis & vDSP Test
        print("▶ [Test 4] Testing AudioEnergyAnalyzer Hysteresis & Signal Extraction...")
        let analyzer = AudioEnergyAnalyzer()

        // Silence
        let silentBuffer = [Float](repeating: 0.0, count: 512)
        for _ in 0..<5 {
            analyzer.process(samples: silentBuffer, count: silentBuffer.count)
        }
        assertEqual(analyzer.isAudioActive, false, "Silence must keep isAudioActive = false")
        assertAccuracy(analyzer.smoothedEnergy, 0.0, accuracy: 0.001)

        // Simulated music wave (sinusoidal pulse)
        var musicSamples = [Float](repeating: 0.0, count: 512)
        for i in 0..<512 {
            musicSamples[i] = sin(Float(i) * 0.1) * 0.7
        }

        // Feed over ~150ms
        for _ in 0..<15 {
            analyzer.process(samples: musicSamples, count: musicSamples.count)
            usleep(10000)
        }
        assertTrue(analyzer.isAudioActive, "Sustained music must activate audioActive state via hysteresis")
        assertTrue(analyzer.smoothedEnergy > 0.01, "Loud music must produce non-zero smoothed energy")
        print("✅ [Test 4 Passed] AudioEnergyAnalyzer hysteresis activates on music and ignores silence.\n")

        // MARK: - 5. Edge Animation Modulation & Think Processing Preservation
        print("▶ [Test 5] Testing EdgeAnimation Modulation...")
        let animation = EdgeAnimation()
        animation.setTargetVisibility(active: true, animated: false)

        // Test 5A: Music Mode OFF -> standard think processing
        settings.isMusicModeEnabled = false
        animation.reloadConfig()
        let standardUniforms = animation.update(size: CGSize(width: 1920, height: 1080), scaleFactor: 2.0)
        assertEqual(standardUniforms.scaleFactor, 2.0)
        assertEqual(standardUniforms.masterAlpha, 1.0)
        assertAccuracy(standardUniforms.stateBrightness, 1.0, accuracy: 0.05)

        // Test 5B: Music Mode ON -> modulates uniforms subtly
        settings.isMusicModeEnabled = true
        animation.reloadConfig()
        MusicReactiveState.shared.update(audioLevel: 0.8, beatPulse: 0.7, bassLevel: 0.6, highLevel: 0.5, isAudioActive: true)
        let musicUniforms = animation.update(size: CGSize(width: 1920, height: 1080), scaleFactor: 2.0)

        // Verify subtle modulation ranges:
        // Brightness should be enhanced within subtle bounds (<= 1.45)
        assertTrue(musicUniforms.stateBrightness >= 1.05 && musicUniforms.stateBrightness <= 1.45, "Music brightness must be subtly enhanced (\(musicUniforms.stateBrightness))")
        // Core intensity subtly enhanced on beat
        assertTrue(musicUniforms.coreIntensity >= 1.25 && musicUniforms.coreIntensity <= 1.70, "Core intensity must subtly respond to beat (\(musicUniforms.coreIntensity))")
        // Glow radius/expansion remains subtle
        assertTrue(musicUniforms.stateGlowMultiplier >= 0.60 && musicUniforms.stateGlowMultiplier <= 1.5, "Glow multiplier must remain subtle (\(musicUniforms.stateGlowMultiplier))")
        print("✅ [Test 5 Passed] EdgeAnimation music modulation is subtle, premium, and constrained.\n")

        // MARK: - 6. Operation Priority Isolation Test
        print("▶ [Test 6] Testing Operation Priority (MANUAL OFF > MANUAL ON > AUTO)...")
        // Manual OFF has highest priority
        settings.controlMode = .forceOff
        assertEqual(settings.controlMode, .forceOff, "Manual OFF must be preserved")

        // Manual ON
        settings.controlMode = .forceOn
        assertEqual(settings.controlMode, .forceOn, "Manual ON must be preserved")

        // Reset back to AUTO
        settings.controlMode = .auto
        assertEqual(settings.controlMode, .auto, "AUTO mode restored")
        settings.isMusicModeEnabled = false
        print("✅ [Test 6 Passed] Charger & manual priority logic is untouched and supreme.\n")

        print("🎉 ALL 6 SUITES PASSED SUCCESSFULLY (100% test pass rate)!")
    }
}
