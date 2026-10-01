import Foundation
import Combine
import SwiftUI

/// Authoritative, single-source settings model for SiriEdge.
/// Reads and preserves existing user preferences stored in UserDefaults.
public final class EdgeSettings: ObservableObject {
    public static let shared = EdgeSettings()
    
    public static let didChangeNotification = Notification.Name("EdgeSettingsDidChange")
    
    // MARK: - Keys
    public enum Keys {
        public static let schemaVersion = "siri_edge_schema_version"
        public static let controlMode = "siri_edge_control_mode"
        public static let defaultAnimation = "siri_edge_default_animation"
        public static let animationSpeed = "siri_edge_animation_speed"
        public static let transparency = "siri_edge_transparency"
        public static let brightness = "siri_edge_brightness"
        public static let glowStrength = "siri_edge_glow_strength"
        public static let fpsMode = "siri_edge_fps_mode"
        public static let customFPS = "siri_edge_custom_fps"
        public static let powerMode = "siri_edge_power_mode"
        public static let isBatterySaverEnabled = "siri_edge_battery_saver_enabled"
        public static let isMusicReactiveEnabled = "siri_edge_music_reactive_enabled"
        public static let musicReactionStrength = "siri_edge_music_reaction_strength"
        public static let audioSource = "siri_edge_audio_source"
        public static let perDisplayFPS = "siri_edge_per_display_fps"
        public static let activityTimeoutMinutes = "siri_edge_activity_timeout_minutes"
        public static let isMusicModeEnabled = "siri_edge_music_mode_enabled"
        public static let musicReactivityLevel = "siri_edge_music_reactivity_level"
        public static let beatResponseLevel = "siri_edge_beat_response_level"
        public static let musicAnimationStyle = "siri_edge_music_animation_style"
    }
    
    // MARK: - Enums
    
    public enum ControlMode: String, CaseIterable, Identifiable {
        case auto = "auto"
        case forceOn = "force_on"
        case forceOff = "force_off"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .auto: return "Auto (Charger-based)"
            case .forceOn: return "Manual ON"
            case .forceOff: return "Manual OFF"
            }
        }
    }
    
    public enum PowerMode: String, CaseIterable, Identifiable {
        case auto = "auto"
        case maximumPerformance = "maximum_performance"
        case performance = "performance"
        case balanced = "balanced"
        case batterySaver = "battery_saver"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .auto: return "Automatic"
            case .maximumPerformance: return "Maximum Performance"
            case .performance: return "Performance"
            case .balanced: return "Balanced"
            case .batterySaver: return "Battery Saver"
            }
        }
    }
    
    public enum FPSMode: Int, CaseIterable, Identifiable {
        case fps30 = 30
        case fps60 = 60
        case fps120 = 120
        case custom = 0
        
        public var id: Int { rawValue }
        
        public var displayName: String {
            switch self {
            case .fps30: return "30 FPS"
            case .fps60: return "60 FPS"
            case .fps120: return "120 FPS (ProMotion)"
            case .custom: return "Custom"
            }
        }
    }
    
    public enum ReactivityLevel: String, CaseIterable, Identifiable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
        
        public var multiplier: Float {
            switch self {
            case .low: return 0.6
            case .medium: return 1.0
            case .high: return 1.5
            }
        }
    }
    
    public enum BeatResponseLevel: String, CaseIterable, Identifiable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
        
        public var multiplier: Float {
            switch self {
            case .low: return 0.6
            case .medium: return 1.0
            case .high: return 1.5
            }
        }
    }
    
    public enum MusicAnimationStyle: String, CaseIterable, Identifiable {
        case subtle = "subtle"
        case dynamic = "dynamic"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .subtle: return "Subtle"
            case .dynamic: return "Dynamic"
            }
        }
    }
    
    // MARK: - Defaults
    public static let defaultControlMode: ControlMode = .forceOn
    public static let defaultAnimationSpeed: Float = 0.65
    public static let defaultTransparency: Float = 0.25
    public static let defaultBrightness: Float = 1.0
    public static let defaultGlowStrength: Float = 0.70
    public static let defaultFPSMode: FPSMode = .fps30
    public static let defaultCustomFPS: Int = 60
    public static let defaultPowerMode: PowerMode = .batterySaver
    public static let defaultBatterySaver: Bool = true
    public static let defaultActivityTimeoutMinutes: Int = 5
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Published Properties
    
    @Published public var schemaVersion: Int
    
    @Published public var controlMode: ControlMode {
        didSet {
            defaults.set(controlMode.rawValue, forKey: Keys.controlMode)
            notifyChanged()
        }
    }
    
    @Published public var defaultAnimation: String {
        didSet {
            defaults.set(defaultAnimation, forKey: Keys.defaultAnimation)
            notifyChanged()
        }
    }
    
    @Published public var animationSpeed: Float {
        didSet {
            defaults.set(animationSpeed, forKey: Keys.animationSpeed)
            notifyChanged()
        }
    }
    
    @Published public var transparency: Float {
        didSet {
            defaults.set(transparency, forKey: Keys.transparency)
            notifyChanged()
        }
    }
    
    @Published public var brightness: Float {
        didSet {
            defaults.set(brightness, forKey: Keys.brightness)
            notifyChanged()
        }
    }
    
    @Published public var glowStrength: Float {
        didSet {
            defaults.set(glowStrength, forKey: Keys.glowStrength)
            notifyChanged()
        }
    }
    
    @Published public var fpsMode: FPSMode {
        didSet {
            defaults.set(fpsMode.rawValue, forKey: Keys.fpsMode)
            notifyChanged()
        }
    }
    
    @Published public var customFPS: Int {
        didSet {
            defaults.set(customFPS, forKey: Keys.customFPS)
            notifyChanged()
        }
    }
    
    @Published public var powerMode: PowerMode {
        didSet {
            defaults.set(powerMode.rawValue, forKey: Keys.powerMode)
            notifyChanged()
        }
    }
    
    @Published public var isBatterySaverEnabled: Bool {
        didSet {
            defaults.set(isBatterySaverEnabled, forKey: Keys.isBatterySaverEnabled)
            notifyChanged()
        }
    }
    
    @Published public var perDisplayFPS: [String: Int] {
        didSet {
            defaults.set(perDisplayFPS, forKey: Keys.perDisplayFPS)
            notifyChanged()
        }
    }
    
    @Published public var activityTimeoutMinutes: Int {
        didSet {
            defaults.set(activityTimeoutMinutes, forKey: Keys.activityTimeoutMinutes)
            notifyChanged()
        }
    }
    
    // Preserved settings (kept in UserDefaults for schema continuity, not actively used in this rebuild)
    @Published public var isMusicReactiveEnabled: Bool {
        didSet {
            defaults.set(isMusicReactiveEnabled, forKey: Keys.isMusicReactiveEnabled)
        }
    }
    
    @Published public var musicReactionStrength: Float {
        didSet {
            defaults.set(musicReactionStrength, forKey: Keys.musicReactionStrength)
        }
    }
    
    @Published public var audioSource: String {
        didSet {
            defaults.set(audioSource, forKey: Keys.audioSource)
        }
    }
    
    // MARK: - Music Mode Properties (Section 12 & 13)
    
    @Published public var isMusicModeEnabled: Bool {
        didSet {
            defaults.set(isMusicModeEnabled, forKey: Keys.isMusicModeEnabled)
            notifyChanged()
        }
    }
    
    @Published public var musicReactivityLevel: ReactivityLevel {
        didSet {
            defaults.set(musicReactivityLevel.rawValue, forKey: Keys.musicReactivityLevel)
            notifyChanged()
        }
    }
    
    @Published public var beatResponseLevel: BeatResponseLevel {
        didSet {
            defaults.set(beatResponseLevel.rawValue, forKey: Keys.beatResponseLevel)
            notifyChanged()
        }
    }
    
    @Published public var musicAnimationStyle: MusicAnimationStyle {
        didSet {
            defaults.set(musicAnimationStyle.rawValue, forKey: Keys.musicAnimationStyle)
            notifyChanged()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Target effective FPS
    public var effectiveTargetFPS: Int {
        switch fpsMode {
        case .fps30: return 30
        case .fps60: return 60
        case .fps120: return 120
        case .custom: return max(15, min(120, customFPS))
        }
    }
    
    /// Whether battery saver optimizations should apply
    public var isBatterySaverActive: Bool {
        if powerMode == .batterySaver { return true }
        if powerMode == .maximumPerformance { return false }
        return isBatterySaverEnabled
    }
    
    // MARK: - Initializer
    
    private init() {
        let d = UserDefaults.standard
        
        let schema = d.object(forKey: Keys.schemaVersion) as? Int ?? 2
        self.schemaVersion = schema
        
        let modeStr = d.string(forKey: Keys.controlMode)
        let mode = modeStr.flatMap { ControlMode(rawValue: $0) } ?? Self.defaultControlMode
        self.controlMode = mode
        
        let anim = d.string(forKey: Keys.defaultAnimation) ?? "thinking"
        self.defaultAnimation = anim
        
        let speed = (d.object(forKey: Keys.animationSpeed) != nil) ? d.float(forKey: Keys.animationSpeed) : Self.defaultAnimationSpeed
        self.animationSpeed = speed
        
        let trans = (d.object(forKey: Keys.transparency) != nil) ? d.float(forKey: Keys.transparency) : Self.defaultTransparency
        self.transparency = trans
        
        let bright = (d.object(forKey: Keys.brightness) != nil) ? d.float(forKey: Keys.brightness) : Self.defaultBrightness
        self.brightness = bright
        
        let glow = (d.object(forKey: Keys.glowStrength) != nil) ? d.float(forKey: Keys.glowStrength) : Self.defaultGlowStrength
        self.glowStrength = glow
        
        let savedFPS = d.integer(forKey: Keys.fpsMode)
        let fps = FPSMode(rawValue: savedFPS) ?? Self.defaultFPSMode
        self.fpsMode = fps
        
        let savedCustomFPS = d.integer(forKey: Keys.customFPS)
        let customFPSVal = savedCustomFPS > 0 ? savedCustomFPS : Self.defaultCustomFPS
        self.customFPS = customFPSVal
        
        let pmStr = d.string(forKey: Keys.powerMode)
        let pm = pmStr.flatMap { PowerMode(rawValue: $0) } ?? Self.defaultPowerMode
        self.powerMode = pm
        
        let isBatterySaver = (d.object(forKey: Keys.isBatterySaverEnabled) != nil) ? d.bool(forKey: Keys.isBatterySaverEnabled) : Self.defaultBatterySaver
        self.isBatterySaverEnabled = isBatterySaver
        
        let perDisplay = (d.dictionary(forKey: Keys.perDisplayFPS) as? [String: Int]) ?? ["Built-in Retina Display": 30]
        self.perDisplayFPS = perDisplay
        
        let savedTimeout = d.integer(forKey: Keys.activityTimeoutMinutes)
        let timeout = savedTimeout > 0 ? savedTimeout : Self.defaultActivityTimeoutMinutes
        self.activityTimeoutMinutes = timeout
        
        let isMusicReactive = (d.object(forKey: Keys.isMusicReactiveEnabled) != nil) ? d.bool(forKey: Keys.isMusicReactiveEnabled) : true
        self.isMusicReactiveEnabled = isMusicReactive
        
        let reactionStrength = (d.object(forKey: Keys.musicReactionStrength) != nil) ? d.float(forKey: Keys.musicReactionStrength) : 0.5
        self.musicReactionStrength = reactionStrength
        
        let audioSrc = d.string(forKey: Keys.audioSource) ?? "System Audio"
        self.audioSource = audioSrc
        
        // Music Mode settings (Default: OFF for safety and zero battery impact when unused)
        let isMusicMode = (d.object(forKey: Keys.isMusicModeEnabled) != nil) ? d.bool(forKey: Keys.isMusicModeEnabled) : false
        self.isMusicModeEnabled = isMusicMode
        
        let reactStr = d.string(forKey: Keys.musicReactivityLevel)
        self.musicReactivityLevel = reactStr.flatMap { ReactivityLevel(rawValue: $0) } ?? .medium
        
        let beatStr = d.string(forKey: Keys.beatResponseLevel)
        self.beatResponseLevel = beatStr.flatMap { BeatResponseLevel(rawValue: $0) } ?? .medium
        
        let animStyleStr = d.string(forKey: Keys.musicAnimationStyle)
        self.musicAnimationStyle = animStyleStr.flatMap { MusicAnimationStyle(rawValue: $0) } ?? .subtle
        
        // Persist confirmed settings to defaults
        d.set(2, forKey: Keys.schemaVersion)
        d.set(mode.rawValue, forKey: Keys.controlMode)
        d.set(anim, forKey: Keys.defaultAnimation)
        d.set(speed, forKey: Keys.animationSpeed)
        d.set(trans, forKey: Keys.transparency)
        d.set(bright, forKey: Keys.brightness)
        d.set(glow, forKey: Keys.glowStrength)
        d.set(fps.rawValue, forKey: Keys.fpsMode)
        d.set(customFPSVal, forKey: Keys.customFPS)
        d.set(pm.rawValue, forKey: Keys.powerMode)
        d.set(isBatterySaver, forKey: Keys.isBatterySaverEnabled)
        d.set(perDisplay, forKey: Keys.perDisplayFPS)
        d.set(timeout, forKey: Keys.activityTimeoutMinutes)
        d.set(isMusicReactive, forKey: Keys.isMusicReactiveEnabled)
        d.set(reactionStrength, forKey: Keys.musicReactionStrength)
        d.set(audioSrc, forKey: Keys.audioSource)
        d.set(isMusicMode, forKey: Keys.isMusicModeEnabled)
        d.set(self.musicReactivityLevel.rawValue, forKey: Keys.musicReactivityLevel)
        d.set(self.beatResponseLevel.rawValue, forKey: Keys.beatResponseLevel)
        d.set(self.musicAnimationStyle.rawValue, forKey: Keys.musicAnimationStyle)
    }
    
    private func notifyChanged() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
