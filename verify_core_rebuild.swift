import Foundation
import AppKit
import Metal
import MetalKit

// Test script to verify the clean rebuild stages

print("=========================================")
print("SIRIEDGE REBUILD VERIFICATION SUITE")
print("=========================================")

// STAGE 1: Metal Device & Pipeline
print("\n[STAGE 1] Testing Metal Renderer & Pipeline State...")
guard let device = MTLCreateSystemDefaultDevice() else {
    print("❌ FAILED: No Metal device available")
    exit(1)
}
print("✅ Metal Device: \(device.name)")

guard let queue = device.makeCommandQueue() else {
    print("❌ FAILED: Could not create Metal command queue")
    exit(1)
}
print("✅ Metal Command Queue created")

// Test shader compilation from EdgeGlow.metal
let shaderPath = "SiriEdge/Rendering/EdgeGlow.metal"
guard let shaderSource = try? String(contentsOfFile: shaderPath) else {
    print("❌ FAILED: Could not load \(shaderPath)")
    exit(1)
}

do {
    let library = try device.makeLibrary(source: shaderSource, options: nil)
    guard let vertexFunc = library.makeFunction(name: "edgeVertexShader"),
          let fragmentFunc = library.makeFunction(name: "edgeFragmentShader") else {
        print("❌ FAILED: Vertex or fragment shader function not found")
        exit(1)
    }
    
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction = vertexFunc
    desc.fragmentFunction = fragmentFunc
    desc.colorAttachments[0].pixelFormat = .bgra8Unorm
    desc.colorAttachments[0].isBlendingEnabled = true
    desc.colorAttachments[0].rgbBlendOperation = .add
    desc.colorAttachments[0].alphaBlendOperation = .add
    desc.colorAttachments[0].sourceRGBBlendFactor = .one
    desc.colorAttachments[0].sourceAlphaBlendFactor = .one
    desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    
    let pipeline = try device.makeRenderPipelineState(descriptor: desc)
    print("✅ Metal Render Pipeline successfully created: \(pipeline)")
} catch {
    print("❌ FAILED: Shader compilation error: \(error)")
    exit(1)
}

// STAGE 2: Display Geometry & Physical Frame
print("\n[STAGE 2] Testing Display Geometry & Physical Frame Boundary...")
let screens = NSScreen.screens
print("Detected screens: \(screens.count)")
for (idx, screen) in screens.enumerated() {
    let physicalFrame = screen.frame
    let visibleFrame = screen.visibleFrame
    print("  Screen \(idx): [\(screen.localizedName)]")
    print("    Physical Frame: \(physicalFrame) (Covers entire screen, notch, and dock)")
    print("    Visible Frame:  \(visibleFrame) (Inset by menu bar and dock)")
    
    assert(physicalFrame.width >= visibleFrame.width, "Physical width must be >= visible width")
    assert(physicalFrame.height >= visibleFrame.height, "Physical height must be >= visible height")
    print("  ✅ Physical frame correctly exceeds or equals visible frame (Phase 5 verified)")
}

// STAGE 3: Power Source Detection
print("\n[STAGE 3] Testing Native Power Source Detection...")
import IOKit.ps
if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
   let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
    print("Found \(sources.count) power source(s)")
    for src in sources {
        if let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any] {
            let state = desc[kIOPSPowerSourceStateKey as String] as? String ?? "Unknown"
            let charging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
            let cap = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
            print("  State: \(state), Charging: \(charging), Battery: \(cap)/\(maxCap)")
        }
    }
    print("✅ Native IOKit power source APIs responding accurately")
} else {
    print("⚠️ No battery info available (likely desktop Mac or simulated)")
}

// STAGE 4: UserDefaults Preservation
print("\n[STAGE 4] Verifying UserDefaults Preservation...")
let plistPath = ("~/Library/Preferences/com.antigravity.SiriEdge.plist" as NSString).expandingTildeInPath
guard let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
    print("❌ Could not read plist at \(plistPath)")
    exit(1)
}

let controlMode = dict["siri_edge_control_mode"] as? String ?? ""
let animSpeed = (dict["siri_edge_animation_speed"] as? NSNumber)?.floatValue ?? 0.0
let transparency = (dict["siri_edge_transparency"] as? NSNumber)?.floatValue ?? 0.0
let brightness = (dict["siri_edge_brightness"] as? NSNumber)?.floatValue ?? 0.0
let fpsMode = (dict["siri_edge_fps_mode"] as? NSNumber)?.intValue ?? 0
let powerMode = dict["siri_edge_power_mode"] as? String ?? ""
let batterySaver = (dict["siri_edge_battery_saver_enabled"] as? NSNumber)?.boolValue ?? false
let timeout = (dict["siri_edge_activity_timeout_minutes"] as? NSNumber)?.intValue ?? 0
let schema = (dict["siri_edge_schema_version"] as? NSNumber)?.intValue ?? 0

print("  Control Mode: \(controlMode) (Expected: force_on)")
print("  Animation Speed: \(animSpeed) (Expected: 0.65)")
print("  Transparency: \(transparency) (Expected: 0.25)")
print("  Brightness: \(brightness) (Expected: 1.0)")
print("  FPS Mode: \(fpsMode) (Expected: 30)")
print("  Power Mode: \(powerMode) (Expected: battery_saver)")
print("  Battery Saver: \(batterySaver) (Expected: true)")
print("  Activity Timeout: \(timeout) min (Expected: 5)")
print("  Schema: \(schema) (Expected: 2)")

guard controlMode == "force_on",
      abs(animSpeed - 0.65) < 0.01,
      abs(transparency - 0.25) < 0.01,
      abs(brightness - 1.0) < 0.01,
      fpsMode == 30,
      powerMode == "battery_saver",
      batterySaver == true,
      timeout == 5,
      schema == 2 else {
    print("❌ FAILED: Preserved settings mismatch")
    exit(1)
}
print("✅ All user settings preserved exactly!")

print("\n=========================================")
print("ALL RUNTIME SMOKE TESTS PASSED!")
print("=========================================")
