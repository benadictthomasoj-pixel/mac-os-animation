import Foundation
import simd
import QuartzCore

/// Matches the Metal shader uniform buffer layout byte-for-byte (128 bytes total, 16-byte aligned).
public struct EdgeUniforms {
    public var resolution: SIMD2<Float>          // 8 bytes (offset 0)
    public var scaleFactor: Float               // 4 bytes (offset 8)
    public var time: Float                      // 4 bytes (offset 12)
    
    public var masterAlpha: Float               // 4 bytes (offset 16)
    public var cornerRadius: Float              // 4 bytes (offset 20)
    public var stateBrightness: Float           // 4 bytes (offset 24)
    public var stateSpeed: Float                // 4 bytes (offset 28)
    
    public var stateGlowMultiplier: Float       // 4 bytes (offset 32)
    public var coreWidth: Float                 // 4 bytes (offset 36)
    public var innerGlowWidth: Float            // 4 bytes (offset 40)
    public var wakeWidth: Float                 // 4 bytes (offset 44)
    
    public var bloomRadius: Float               // 4 bytes (offset 48)
    public var baseIntensity: Float             // 4 bytes (offset 52)
    public var coreIntensity: Float             // 4 bytes (offset 56)
    public var wakeIntensity: Float             // 4 bytes (offset 60)
    
    public var bloomIntensity: Float            // 4 bytes (offset 64)
    public var maxGlowExtent: Float             // 4 bytes (offset 68)
    public var forwardPushLength: Float         // 4 bytes (offset 72)
    public var backwardWakeLength: Float        // 4 bytes (offset 76)
    
    public var vibrancy: Float                  // 4 bytes (offset 80)
    public var overallOpacity: Float            // 4 bytes (offset 84)
    public var pad0: Float                      // 4 bytes (offset 88)
    public var pad1: Float                      // 4 bytes (offset 92)
    
    public var pulsePositions: SIMD4<Float>     // 16 bytes (offset 96)
    public var pulseIntensities: SIMD4<Float>   // 16 bytes (offset 112)
    // Total size: 128 bytes (16-byte aligned)
    
    public init(
        resolution: SIMD2<Float> = SIMD2<Float>(1920, 1080),
        scaleFactor: Float = 2.0,
        time: Float = 0.0,
        masterAlpha: Float = 1.0,
        cornerRadius: Float = 14.0,
        stateBrightness: Float = 1.0,
        stateSpeed: Float = 0.65,
        stateGlowMultiplier: Float = 1.0,
        coreWidth: Float = 2.0,
        innerGlowWidth: Float = 4.5,
        wakeWidth: Float = 6.0,
        bloomRadius: Float = 12.0,
        baseIntensity: Float = 0.50,
        coreIntensity: Float = 1.25,
        wakeIntensity: Float = 0.55,
        bloomIntensity: Float = 0.25,
        maxGlowExtent: Float = 20.0,
        forwardPushLength: Float = 0.045,
        backwardWakeLength: Float = 0.140,
        vibrancy: Float = 1.0,
        overallOpacity: Float = 1.0,
        pad0: Float = 0.0,
        pad1: Float = 0.0,
        pulsePositions: SIMD4<Float> = SIMD4<Float>(0.0, 0.333, 0.666, 0.0),
        pulseIntensities: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 0.0)
    ) {
        self.resolution = resolution
        self.scaleFactor = scaleFactor
        self.time = time
        self.masterAlpha = masterAlpha
        self.cornerRadius = cornerRadius
        self.stateBrightness = stateBrightness
        self.stateSpeed = stateSpeed
        self.stateGlowMultiplier = stateGlowMultiplier
        self.coreWidth = coreWidth
        self.innerGlowWidth = innerGlowWidth
        self.wakeWidth = wakeWidth
        self.bloomRadius = bloomRadius
        self.baseIntensity = baseIntensity
        self.coreIntensity = coreIntensity
        self.wakeIntensity = wakeIntensity
        self.bloomIntensity = bloomIntensity
        self.maxGlowExtent = maxGlowExtent
        self.forwardPushLength = forwardPushLength
        self.backwardWakeLength = backwardWakeLength
        self.vibrancy = vibrancy
        self.overallOpacity = overallOpacity
        self.pad0 = pad0
        self.pad1 = pad1
        self.pulsePositions = pulsePositions
        self.pulseIntensities = pulseIntensities
    }
}

/// Dynamic constants and cache for the perimeter renderer
public final class EdgeAnimation {
    // MARK: - Timing & State
    
    private var lastFrameTime: CFTimeInterval
    private var accumulatedTime: Double = 0.0
    
    public private(set) var currentAlpha: Float = 0.0
    public private(set) var targetAlpha: Float = 0.0
    private var fadeStartTime: CFTimeInterval = 0.0
    private var fadeStartAlpha: Float = 0.0
    
    public var cornerRadius: Float = 14.0
    
    // Cached render parameters from EdgeSettings
    public struct Config {
        public var speed: Float = 0.65
        public var brightness: Float = 1.0
        public var transparency: Float = 0.25
        public var glowStrength: Float = 0.70
        public var isBatterySaver: Bool = true
        public var isMusicModeEnabled: Bool = false
        public var reactivityMultiplier: Float = 1.0
        public var beatMultiplier: Float = 1.0
        public var musicAnimationStyle: EdgeSettings.MusicAnimationStyle = .subtle
    }
    
    public var config: Config = Config()
    
    public init() {
        let now = CACurrentMediaTime()
        self.lastFrameTime = now
        reloadConfig()
    }
    
    public func reloadConfig() {
        let s = EdgeSettings.shared
        self.config = Config(
            speed: s.animationSpeed,
            brightness: s.brightness,
            transparency: s.transparency,
            glowStrength: s.glowStrength,
            isBatterySaver: s.isBatterySaverActive,
            isMusicModeEnabled: s.isMusicModeEnabled,
            reactivityMultiplier: s.musicReactivityLevel.multiplier,
            beatMultiplier: s.beatResponseLevel.multiplier,
            musicAnimationStyle: s.musicAnimationStyle
        )
    }
    
    public func resetTimeline() {
        self.lastFrameTime = CACurrentMediaTime()
    }
    
    public func setTargetVisibility(active: Bool, animated: Bool = true) {
        targetAlpha = active ? 1.0 : 0.0
        if animated {
            fadeStartTime = CACurrentMediaTime()
            fadeStartAlpha = currentAlpha
        } else {
            currentAlpha = targetAlpha
        }
    }
    
    public var isFullyFadedOut: Bool {
        return currentAlpha <= 0.001 && targetAlpha <= 0.001
    }
    
    // MARK: - Direct Frame Update (Zero Allocations)
    
    @discardableResult
    public func updateDirect(
        size: CGSize,
        scaleFactor: CGFloat,
        into bufferPointer: UnsafeMutablePointer<EdgeUniforms>
    ) -> Bool {
        let now = CACurrentMediaTime()
        let dt = now - lastFrameTime
        lastFrameTime = now
        
        // Continuous time accumulation scaled by speed multiplier
        accumulatedTime += dt * Double(config.speed)
        let t = Float(accumulatedTime)
        
        // Smooth fade in / out interpolation
        if currentAlpha != targetAlpha {
            let elapsedFade = now - fadeStartTime
            let duration: Double = (targetAlpha > 0.5) ? 0.40 : 0.50
            let progress = Float(min(max(elapsedFade / duration, 0.0), 1.0))
            let smoothProgress = progress * progress * (3.0 - 2.0 * progress)
            currentAlpha = fadeStartAlpha + (targetAlpha - fadeStartAlpha) * smoothProgress
        }
        
        if isFullyFadedOut {
            bufferPointer.pointee.masterAlpha = 0.0
            return false
        }
        
        // Check for active Music Mode modulation
        var audioLevel: Float = 0.0
        var beatPulse: Float = 0.0
        var bassLevel: Float = 0.0
        
        if config.isMusicModeEnabled {
            let snap = MusicReactiveState.shared.getSnapshot()
            if snap.isAudioActive {
                audioLevel = snap.audioLevel
                beatPulse = snap.beatPulse
                bassLevel = snap.bassLevel
            }
        }
        
        // Base pulse speed: modulated subtly by music energy and beat transients
        let speedBoost: Float
        if config.isMusicModeEnabled && (audioLevel > 0.001 || beatPulse > 0.001) {
            let isDynamic = (config.musicAnimationStyle == .dynamic)
            let levelEffect = isDynamic ? (audioLevel * 0.14) : (audioLevel * 0.07)
            let beatEffect = isDynamic ? (beatPulse * 0.22) : (beatPulse * 0.12)
            speedBoost = (levelEffect + beatEffect) * config.reactivityMultiplier
        } else {
            speedBoost = 0.0
        }
        
        let speed: Float = 0.22 + speedBoost
        let p0 = fmod(t * speed, 1.0)
        let p1 = fmod(t * speed + 0.333, 1.0)
        let p2 = fmod(t * speed + 0.666, 1.0)
        
        let pulsePos = SIMD4<Float>(p0 < 0 ? p0 + 1.0 : p0,
                                   p1 < 0 ? p1 + 1.0 : p1,
                                   p2 < 0 ? p2 + 1.0 : p2,
                                   0.0)
        
        let basePulseInt: Float = 1.0
        let pulseInt = SIMD4<Float>(basePulseInt * 1.25, basePulseInt * 1.15, basePulseInt * 1.20, 0.0)
        
        // Subtly modulate halo and brightness with audio energy
        let glowBoost = (bassLevel * 0.15 * config.reactivityMultiplier + beatPulse * 0.20 * config.beatMultiplier)
        let glowMul = config.glowStrength * (1.0 + glowBoost) * (config.isBatterySaver ? 0.90 : 1.0)
        
        let brightnessBoost = (audioLevel * 0.12 * config.reactivityMultiplier + beatPulse * 0.18 * config.beatMultiplier)
        let effectiveBrightness = min(1.35, config.brightness * (1.0 + brightnessBoost))
        
        let coreIntensity = 1.25 * (1.0 + beatPulse * 0.18 * config.beatMultiplier)
        let wakeBoost = bassLevel * 0.15 * config.reactivityMultiplier + beatPulse * 0.20 * config.beatMultiplier
        let bloomBoost = audioLevel * 0.15 * config.reactivityMultiplier + beatPulse * 0.20 * config.beatMultiplier
        
        bufferPointer.pointee.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
        bufferPointer.pointee.scaleFactor = Float(scaleFactor)
        bufferPointer.pointee.time = t
        bufferPointer.pointee.masterAlpha = currentAlpha
        bufferPointer.pointee.cornerRadius = cornerRadius
        bufferPointer.pointee.stateBrightness = effectiveBrightness
        bufferPointer.pointee.stateSpeed = config.speed
        bufferPointer.pointee.stateGlowMultiplier = glowMul
        bufferPointer.pointee.coreWidth = 2.0
        bufferPointer.pointee.innerGlowWidth = 4.5
        bufferPointer.pointee.wakeWidth = 6.0
        bufferPointer.pointee.bloomRadius = 12.0
        bufferPointer.pointee.baseIntensity = 0.50 * (config.isBatterySaver ? 0.85 : 1.0)
        bufferPointer.pointee.coreIntensity = coreIntensity
        bufferPointer.pointee.wakeIntensity = (0.55 + wakeBoost) * (config.isBatterySaver ? 0.75 : 1.0)
        bufferPointer.pointee.bloomIntensity = (0.25 + bloomBoost) * (config.isBatterySaver ? 0.80 : 1.0)
        bufferPointer.pointee.maxGlowExtent = 20.0
        bufferPointer.pointee.forwardPushLength = 0.045
        bufferPointer.pointee.backwardWakeLength = 0.140
        bufferPointer.pointee.vibrancy = 1.0
        bufferPointer.pointee.overallOpacity = config.transparency
        bufferPointer.pointee.pad0 = 0.0
        bufferPointer.pointee.pad1 = 0.0
        bufferPointer.pointee.pulsePositions = pulsePos
        bufferPointer.pointee.pulseIntensities = pulseInt
        
        return true
    }
    
    public func update(size: CGSize, scaleFactor: CGFloat) -> EdgeUniforms {
        var uniforms = EdgeUniforms()
        _ = withUnsafeMutablePointer(to: &uniforms) { ptr in
            updateDirect(size: size, scaleFactor: scaleFactor, into: ptr)
        }
        return uniforms
    }
}
