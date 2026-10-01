import Foundation
import QuartzCore
import os.lock
import Combine

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
public final class MusicReactiveState: ObservableObject, @unchecked Sendable {
    public static let shared = MusicReactiveState()
    
    @Published public private(set) var isAudioActive: Bool = false
    @Published public private(set) var beatPulse: Float = 0.0
    
    private var lock = os_unfair_lock_s()
    private var currentSnapshot = AudioSnapshot()
    private var lastUIUpdateTime: Double = 0.0
    
    private init() {}
    
    /// Updates shared audio metrics from background audio processor (Zero allocations).
    public func update(
        audioLevel: Float,
        beatPulse: Float,
        bassLevel: Float,
        highLevel: Float,
        isAudioActive: Bool
    ) {
        let now = CACurrentMediaTime()
        os_unfair_lock_lock(&lock)
        currentSnapshot.audioLevel = audioLevel
        currentSnapshot.beatPulse = beatPulse
        currentSnapshot.bassLevel = bassLevel
        currentSnapshot.highLevel = highLevel
        currentSnapshot.isAudioActive = isAudioActive
        currentSnapshot.timestamp = now
        os_unfair_lock_unlock(&lock)
        
        // Throttled UI publish to main thread (~10Hz)
        if now - lastUIUpdateTime >= 0.10 {
            lastUIUpdateTime = now
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.isAudioActive != isAudioActive {
                    self.isAudioActive = isAudioActive
                }
                self.beatPulse = beatPulse
            }
        }
    }
    
    /// Fast, non-blocking query used by EdgeRenderer in draw(in:) with zero heap allocations.
    public func getSnapshot() -> AudioSnapshot {
        os_unfair_lock_lock(&lock)
        let snap = currentSnapshot
        os_unfair_lock_unlock(&lock)
        return snap
    }
    
    public func snapshot() -> AudioSnapshot {
        return getSnapshot()
    }
    
    /// Resets all values to silence when audio stops or Music Mode is toggled off.
    public func reset() {
        os_unfair_lock_lock(&lock)
        currentSnapshot = AudioSnapshot()
        os_unfair_lock_unlock(&lock)
        DispatchQueue.main.async { [weak self] in
            self?.isAudioActive = false
            self?.beatPulse = 0.0
        }
    }
}
