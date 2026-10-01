import Foundation
import IOKit.ps
import Combine

/// Minimal, event-driven macOS power source monitor.
/// Uses native IOKit runloop notifications with zero polling overhead.
public final class PowerSource: ObservableObject {
    public static let shared = PowerSource()
    public static let powerSourceDidChangeNotification = Notification.Name("PowerSourceDidChangeNotification")
    
    @Published public private(set) var isChargerConnected: Bool = true
    @Published public private(set) var isBattery: Bool = false
    @Published public private(set) var batteryPercentage: Int? = nil
    
    private var runLoopSource: CFRunLoopSource?
    
    private init() {
        updateState()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    public func updateState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            self.isChargerConnected = true
            self.isBattery = false
            return
        }
        
        var batteryFound = false
        var percent: Int? = nil
        
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                if let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                    if state == (kIOPSBatteryPowerValue as String) {
                        batteryFound = true
                    }
                }
                if let cur = desc[kIOPSCurrentCapacityKey as String] as? Int,
                   let max = desc[kIOPSMaxCapacityKey as String] as? Int, max > 0 {
                    percent = Int(round(Double(cur) / Double(max) * 100.0))
                }
            }
        }
        
        let newChargerState = !batteryFound
        let changed = (self.isChargerConnected != newChargerState)
        
        self.isChargerConnected = newChargerState
        self.isBattery = batteryFound
        self.batteryPercentage = percent
        
        if changed {
            NotificationCenter.default.post(name: Self.powerSourceDidChangeNotification, object: self)
        }
    }
    
    private func startMonitoring() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let monitor = Unmanaged<PowerSource>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.updateState()
            }
        }, context)?.takeRetainedValue()
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
    
    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
    }
}
