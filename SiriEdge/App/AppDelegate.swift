import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.antigravity.SiriEdge", category: "AppDelegate")

/// Main application delegate managing menu bar item, settings window, and trigger state machine.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    private let overlayManager = OverlayManager.shared
    private let powerSource = PowerSource.shared
    private let settings = EdgeSettings.shared
    
    // 5-minute timeout timer for Manual ON mode
    private var manualTimeoutTimer: Timer?
    
    // Simulated power state for testing without physical cable unplugging
    private var simulatedChargerConnected: Bool? = nil
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("SiriEdge launched")
        
        // Accessory mode (no Dock icon, menu bar only)
        NSApp.setActivationPolicy(.accessory)
        
        parseCommandLineArguments()
        
        setupStatusItem()
        overlayManager.setupOverlays()
        
        // Listen to notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerSourceChanged),
            name: PowerSource.powerSourceDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: EdgeSettings.didChangeNotification,
            object: nil
        )
        
        evaluateTriggerState(animated: true)
    }
    
    private func parseCommandLineArguments() {
        let args = CommandLine.arguments
        if args.contains("--auto") {
            settings.controlMode = .auto
        } else if args.contains("--force-on") {
            settings.controlMode = .forceOn
        } else if args.contains("--force-off") {
            settings.controlMode = .forceOff
        }
        
        if args.contains("--music") {
            settings.isMusicModeEnabled = true
        } else if args.contains("--no-music") {
            settings.isMusicModeEnabled = false
        }
        
        if args.contains("--simulate-ac") {
            self.simulatedChargerConnected = true
        } else if args.contains("--simulate-battery") {
            self.simulatedChargerConnected = false
        }
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            // Load bundled Retina menu bar icon
            if let icon = NSImage(named: "SiriEdgeMenuBarIcon@2x") ??
                          NSImage(named: "SiriEdgeMenuBarIcon") ??
                          NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/SiriEdgeMenuBarIcon@2x.png") ??
                          NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/SiriEdgeMenuBarIcon.png") {
                icon.isTemplate = false
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
            } else {
                button.image = makeCircularLogo(size: 18)
            }
            
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.title = ""
            button.toolTip = "SiriEdge"
        }
        
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Mode Selection
        let modeHeader = NSMenuItem(title: "Operation Mode:", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)
        
        let autoItem = NSMenuItem(title: "  Auto (Charger-based)", action: #selector(setModeAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = settings.controlMode == .auto ? .on : .off
        menu.addItem(autoItem)
        
        let onItem = NSMenuItem(title: "  Manual ON", action: #selector(setModeOn), keyEquivalent: "")
        onItem.target = self
        onItem.state = settings.controlMode == .forceOn ? .on : .off
        menu.addItem(onItem)
        
        let offItem = NSMenuItem(title: "  Manual OFF", action: #selector(setModeOff), keyEquivalent: "")
        offItem.target = self
        offItem.state = settings.controlMode == .forceOff ? .on : .off
        menu.addItem(offItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit SiriEdge", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        item.menu = menu
        self.statusItem = item
    }
    
    private func makeCircularLogo(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        let rect = NSRect(origin: .zero, size: NSSize(width: size, height: size)).insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: rect)
        NSColor.systemCyan.setFill()
        path.fill()
        NSColor.systemPurple.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        img.unlockFocus()
        return img
    }
    
    // MARK: - Mode & State Machine (Priority: MANUAL OFF > MANUAL ON > AUTO)
    
    @objc public func evaluateTriggerState(animated: Bool = true) {
        let isCharger = simulatedChargerConnected ?? powerSource.isChargerConnected
        
        switch settings.controlMode {
        case .forceOff:
            // MANUAL OFF: Always OFF
            invalidateManualTimeout()
            overlayManager.hide(animated: animated)
            
        case .forceOn:
            // MANUAL ON: Always ON (with 5-minute timeout)
            overlayManager.show(animated: animated)
            startManualTimeout()
            
        case .auto:
            // AUTO: Follows Charger State ONLY
            invalidateManualTimeout()
            if isCharger {
                overlayManager.show(animated: animated)
            } else {
                overlayManager.hide(animated: animated)
            }
        }
        
        updateMenuStates()
        
        // Manage background system audio capture strictly based on overlay visibility and Music Mode setting
        if overlayManager.isVisible && settings.isMusicModeEnabled {
            SystemAudioMonitor.shared.startMonitoring()
        } else {
            SystemAudioMonitor.shared.stopMonitoring()
        }
    }
    
    private func startManualTimeout() {
        invalidateManualTimeout()
        let timeoutSeconds = Double(settings.activityTimeoutMinutes) * 60.0
        manualTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            logger.info("Manual ON activity timeout reached (\(self.settings.activityTimeoutMinutes) min), hiding overlay")
            self.overlayManager.hide(animated: true)
        }
    }
    
    private func invalidateManualTimeout() {
        manualTimeoutTimer?.invalidate()
        manualTimeoutTimer = nil
    }
    
    @objc private func handlePowerSourceChanged() {
        evaluateTriggerState(animated: true)
    }
    
    @objc private func handleSettingsChanged() {
        evaluateTriggerState(animated: true)
    }
    
    private func updateMenuStates() {
        guard let menu = statusItem?.menu else { return }
        for item in menu.items {
            if item.action == #selector(setModeAuto) {
                item.state = settings.controlMode == .auto ? .on : .off
            } else if item.action == #selector(setModeOn) {
                item.state = settings.controlMode == .forceOn ? .on : .off
            } else if item.action == #selector(setModeOff) {
                item.state = settings.controlMode == .forceOff ? .on : .off
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func setModeAuto() {
        settings.controlMode = .auto
    }
    
    @objc private func setModeOn() {
        settings.controlMode = .forceOn
    }
    
    @objc private func setModeOff() {
        settings.controlMode = .forceOff
    }
    
    @objc public func openSettingsWindow() {
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "SiriEdge Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        SystemAudioMonitor.shared.stopMonitoring()
        overlayManager.hide(animated: false)
        NSApp.terminate(nil)
    }
}
