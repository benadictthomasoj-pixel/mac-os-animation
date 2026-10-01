import Foundation
import IOKit.ps
import Combine
import AppKit

/// Minimal, event-driven macOS power source monitor.
/// Uses native IOKit runloop notifications + Darwin notifyd events with zero polling overhead.
public final class PowerSource: ObservableObject {
    public static let shared = PowerSource()
    public static let powerSourceDidChangeNotification = Notification.Name("PowerSourceDidChangeNotification")
    
    @Published public private(set) var isChargerConnected: Bool = true
    @Published public private(set) var isBattery: Bool = false
    @Published public private(set) var batteryPercentage: Int? = nil
    
    private var runLoopSource: CFRunLoopSource?
    private var isInitialized = false
    
    private init() {
        updateState(isInitial: true)
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    public func updateState(isInitial: Bool = false) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            self.isChargerConnected = true
            self.isBattery = false
            if isInitial {
                print("[POWER] initial state = AC (fallback)")
            }
            return
        }
        
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []
        
        // 1. Check providing power source type (AC Power vs Battery Power)
        let providerType = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String?
        let isDrawingAC = (providerType == (kIOPMACPowerKey as String))
        
        // 2. Check external power adapter details (non-nil & non-empty when physically attached)
        let adapterDetails = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        let hasAdapter = (adapterDetails != nil && !adapterDetails!.isEmpty)
        
        // 3. Inspect individual power sources (internal battery / AC status)
        var isACSource = false
        var isCharging = false
        var percent: Int? = nil
        var foundBattery = false
        
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                if let type = desc[kIOPSTypeKey as String] as? String, type == (kIOPSInternalBatteryType as String) {
                    foundBattery = true
                }
                if let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                    if state == (kIOPSACPowerValue as String) {
                        isACSource = true
                    }
                }
                if let charging = desc[kIOPSIsChargingKey as String] as? Bool, charging {
                    isCharging = true
                }
                if let cur = desc[kIOPSCurrentCapacityKey as String] as? Int,
                   let max = desc[kIOPSMaxCapacityKey as String] as? Int, max > 0 {
                    percent = Int(round(Double(cur) / Double(max) * 100.0))
                }
            }
        }
        
        // Comprehensive AC / Charger connection evaluation:
        // System is on AC/Charger if drawing AC, adapter attached, source is in AC state, or battery is charging.
        // For desktop Macs without an internal battery, foundBattery is false, so it is always on AC.
        let newChargerState: Bool
        if !foundBattery {
            newChargerState = true
        } else {
            newChargerState = isDrawingAC || hasAdapter || isACSource || isCharging
        }
        
        let changed = (self.isChargerConnected != newChargerState) || !isInitialized
        isInitialized = true
        
        self.isChargerConnected = newChargerState
        self.isBattery = !newChargerState
        self.batteryPercentage = percent
        
        let stateStr = newChargerState ? "AC" : "BATTERY"
        if isInitial {
            print("[POWER] initial state = \(stateStr)")
        } else if changed {
            print("[POWER] current state = \(stateStr)")
            NotificationCenter.default.post(name: Self.powerSourceDidChangeNotification, object: self)
        }
    }
    
    private func startMonitoring() {
        // 1. Native IOKit RunLoop source
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let monitor = Unmanaged<PowerSource>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                print("[POWER] notification received")
                monitor.updateState()
            }
        }, context)?.takeRetainedValue()
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        
        // 2. System wake and display power notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[POWER] notification received (wake)")
            self?.updateState()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[POWER] notification received (screens wake)")
            self?.updateState()
        }
    }
    
    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
