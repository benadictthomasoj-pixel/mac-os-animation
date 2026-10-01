import Foundation
import QuartzCore
import os.lock

/// Thread-safe, allocation-free snapshot of current music and beat metrics.
public struct AudioSnapshot: Sendable {
    public var audioLevel: Float = 0.0       // 0.0 ... 1.0 (Smoothed RMS energy)
    public var beatPulse: Float = 0.0        // 0.0 ... 1.0 (Transient beat impulse with smooth decay)
    public var bassLevel: Float = 0.0        // 0.0 ... 1.0 (Low-frequency energy)
    public var highLevel: Float = 0.0        // 0.0 ... 1.0 (High-frequency sparkle)
    public var isAudioActive: Bool = false    // True when system audio is currently playing
    public var timestamp: CFTimeInterval = 0.0
    
    public init(
        audioLevel: Float = 0.0,
        beatPulse: Float = 0.0,
        bassLevel: Float = 0.0,
        highLevel: Float = 0.0,
        isAudioActive: Bool = false,
        timestamp: CFTimeInterval = 0.0
    ) {
        self.audioLevel = audioLevel
        self.beatPulse = beatPulse
        self.bassLevel = bassLevel
        self.highLevel = highLevel
        self.isAudioActive = isAudioActive
        self.timestamp = timestamp
    }
}

/// Shared, thread-safe state container bridging the background audio queue to the Metal render loop.
/// Zero per-frame allocations, lock-protected with os_unfair_lock.
public final class MusicReactiveState: @unchecked Sendable {
    public static let shared = MusicReactiveState()
    
    private var lock = os_unfair_lock_s()
    private var currentSnapshot = AudioSnapshot()
    
    private init() {}
    
    /// Updates shared audio metrics from background audio processor (Zero allocations).
    public func update(
        audioLevel: Float,
        beatPulse: Float,
        bassLevel: Float,
        highLevel: Float,
        isAudioActive: Bool
    ) {
        os_unfair_lock_lock(&lock)
        currentSnapshot.audioLevel = audioLevel
        currentSnapshot.beatPulse = beatPulse
        currentSnapshot.bassLevel = bassLevel
        currentSnapshot.highLevel = highLevel
        currentSnapshot.isAudioActive = isAudioActive
        currentSnapshot.timestamp = CACurrentMediaTime()
        os_unfair_lock_unlock(&lock)
    }
    
    /// Fast, non-blocking query used by EdgeRenderer in draw(in:) with zero heap allocations.
    public func getSnapshot() -> AudioSnapshot {
        os_unfair_lock_lock(&lock)
        let snap = currentSnapshot
        os_unfair_lock_unlock(&lock)
        return snap
    }
    
    /// Resets all values to silence when audio stops or Music Mode is toggled off.
    public func reset() {
        os_unfair_lock_lock(&lock)
        currentSnapshot = AudioSnapshot()
        os_unfair_lock_unlock(&lock)
    }
}
