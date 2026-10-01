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
}
