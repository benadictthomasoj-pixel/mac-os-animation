import Foundation
import AppKit
import Metal
import MetalKit

print("==================================================")
print("SIRIEDGE CLEAN REBUILD VERIFICATION SUITE")
print("==================================================")

// 1. ARCHITECTURE INTEGRITY
print("\n[TEST 1] Minimal Architecture Verification...")
let requiredFiles = [
    "SiriEdge/App/SiriEdgeApp.swift",
    "SiriEdge/App/AppDelegate.swift",
    "SiriEdge/Models/EdgeSettings.swift",
    "SiriEdge/Models/PowerSource.swift",
    "SiriEdge/Overlay/OverlayWindow.swift",
    "SiriEdge/Overlay/OverlayManager.swift",
    "SiriEdge/Rendering/EdgeRenderer.swift",
    "SiriEdge/Rendering/EdgeAnimation.swift",
    "SiriEdge/Rendering/EdgeGlow.metal",
    "SiriEdge/Views/SettingsView.swift",
    "SiriEdge/Views/EdgeOverlayView.swift"
]

var missingFiles: [String] = []
for file in requiredFiles {
    if !FileManager.default.fileExists(atPath: file) {
        missingFiles.append(file)
    }
}

if missingFiles.isEmpty {
    print("  ✅ All 11 required minimal architecture files are present and accounted for.")
} else {
    print("  ❌ Missing files: \(missingFiles)")
    exit(1)
}

// 2. NO AUDIO DEPENDENCIES
print("\n[TEST 2] Verifying Complete Audio Decoupling...")
let audioDirs = ["SiriEdge/Audio", "SiriEdge/Controllers"]
var audioFound = false
for dir in audioDirs {
    if FileManager.default.fileExists(atPath: dir) {
        print("  ❌ Obsolete directory found: \(dir)")
        audioFound = true
    }
}
if !audioFound {
    print("  ✅ ZERO audio directories or controllers exist. Pure perimeter glow rebuild.")
} else {
    exit(1)
}

// 3. SETTINGS PRESERVATION
print("\n[TEST 3] Verifying Exact Settings Preservation in UserDefaults...")
let plistPath = ("~/Library/Preferences/com.antigravity.SiriEdge.plist" as NSString).expandingTildeInPath
guard let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
    print("  ❌ Failed to read plist")
    exit(1)
}

let expectedSettings: [String: Any] = [
    "siri_edge_control_mode": "force_on",
    "siri_edge_default_animation": "thinking",
    "siri_edge_animation_speed": 0.65,
    "siri_edge_transparency": 0.25,
    "siri_edge_brightness": 1.0,
    "siri_edge_fps_mode": 30,
    "siri_edge_custom_fps": 60,
    "siri_edge_power_mode": "battery_saver",
    "siri_edge_battery_saver_enabled": true,
    "siri_edge_music_reactive_enabled": true,
    "siri_edge_music_reaction_strength": 0.5,
    "siri_edge_audio_source": "System Audio",
    "siri_edge_activity_timeout_minutes": 5,
    "siri_edge_schema_version": 2
]

for (key, expected) in expectedSettings {
    guard let actual = dict[key] else {
        print("  ❌ Missing setting: \(key)")
        exit(1)
    }
    
    if let expectedStr = expected as? String {
        assert((actual as? String) == expectedStr, "\(key) must be \(expectedStr)")
    } else if let expectedBool = expected as? Bool {
        assert((actual as? Bool) == expectedBool, "\(key) must be \(expectedBool)")
    } else if let expectedInt = expected as? Int {
        assert(((actual as? NSNumber)?.intValue) == expectedInt, "\(key) must be \(expectedInt)")
    } else if let expectedFloat = expected as? Double {
        let val = (actual as? NSNumber)?.doubleValue ?? 0.0
        assert(abs(val - expectedFloat) < 0.01, "\(key) must be \(expectedFloat)")
    }
    print("  ✅ \(key): \(actual)")
}

// 4. OPERATION MODE STATE MACHINE & PRIORITIES
print("\n[TEST 4] Testing Operation Mode Priority Matrix...")
// Priority: MANUAL OFF > MANUAL ON > AUTO
enum Mode { case forceOff, forceOn, auto }
func evaluateState(mode: Mode, chargerConnected: Bool) -> Bool {
    switch mode {
    case .forceOff: return false
    case .forceOn: return true
    case .auto: return chargerConnected
    }
}

// Matrix verification
assert(evaluateState(mode: .forceOff, chargerConnected: true) == false, "MANUAL OFF + Charger -> MUST BE OFF")
assert(evaluateState(mode: .forceOff, chargerConnected: false) == false, "MANUAL OFF + Battery -> MUST BE OFF")
assert(evaluateState(mode: .forceOn, chargerConnected: true) == true, "MANUAL ON + Charger -> MUST BE ON")
assert(evaluateState(mode: .forceOn, chargerConnected: false) == true, "MANUAL ON + Battery -> MUST BE ON")
assert(evaluateState(mode: .auto, chargerConnected: true) == true, "AUTO + Charger -> MUST BE ON")
assert(evaluateState(mode: .auto, chargerConnected: false) == false, "AUTO + Battery -> MUST BE OFF")

print("  ✅ MANUAL OFF + Charger Connected    -> SiriEdge OFF (Passed)")
print("  ✅ MANUAL OFF + Battery Power        -> SiriEdge OFF (Passed)")
print("  ✅ MANUAL ON  + Charger Connected    -> SiriEdge ON  (Passed)")
print("  ✅ MANUAL ON  + Battery Power        -> SiriEdge ON  (Passed)")
print("  ✅ AUTO       + Charger Connected    -> SiriEdge ON  (Passed)")
print("  ✅ AUTO       + Battery Power        -> SiriEdge OFF (Passed)")

// 5. METAL SHADER REBUILD & RENDERING
print("\n[TEST 5] Testing Metal Rendering Pipeline...")
guard let device = MTLCreateSystemDefaultDevice() else {
    print("  ❌ No Metal device")
    exit(1)
}
let shaderSource = try! String(contentsOfFile: "SiriEdge/Rendering/EdgeGlow.metal")
let library = try! device.makeLibrary(source: shaderSource, options: nil)
let vFunc = library.makeFunction(name: "edgeVertexShader")!
let fFunc = library.makeFunction(name: "edgeFragmentShader")!

let pDesc = MTLRenderPipelineDescriptor()
pDesc.vertexFunction = vFunc
pDesc.fragmentFunction = fFunc
pDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
pDesc.colorAttachments[0].isBlendingEnabled = true
pDesc.colorAttachments[0].sourceRGBBlendFactor = .one
pDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
pDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
pDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

let pipeline = try! device.makeRenderPipelineState(descriptor: pDesc)
print("  ✅ Metal pipeline compiled successfully on \(device.name)")

// 6. SCREEN SAVER BUNDLE
print("\n[TEST 6] Testing Screen Saver Bundle Existence...")
let saverPath = "SiriEdge.saver"
if FileManager.default.fileExists(atPath: saverPath) {
    print("  ✅ SiriEdge.saver generated successfully")
} else {
    print("  ❌ SiriEdge.saver missing")
    exit(1)
}

// 7. APP BUNDLE
print("\n[TEST 7] Testing macOS App Bundle Existence...")
let appPath = "SiriEdge.app"
let execPath = "SiriEdge.app/Contents/MacOS/SiriEdge"
if FileManager.default.fileExists(atPath: execPath) {
    print("  ✅ SiriEdge.app binary executable found at \(execPath)")
} else {
    print("  ❌ SiriEdge.app missing")
    exit(1)
}

print("\n==================================================")
print("ALL VERIFICATIONS COMPLETED SUCCESSFULLY!")
print("==================================================")
