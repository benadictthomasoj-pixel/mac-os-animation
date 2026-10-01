import AppKit
import os.log

private let logger = Logger(subsystem: "com.antigravity.SiriEdge", category: "OverlayManager")

/// Manages transparent overlay windows across all physical connected displays.
public final class OverlayManager {
    public static let shared = OverlayManager()
    
    public private(set) var windows: [OverlayWindow] = []
    public private(set) var isVisible: Bool = false
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func setupOverlays() {
        // Tear down any existing windows first
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        
        let screens = NSScreen.screens
        for screen in screens {
            guard let renderer = EdgeRenderer() else {
                logger.error("Failed to initialize EdgeRenderer for screen")
                continue
            }
            
            let window = OverlayWindow(screen: screen, renderer: renderer)
            
            // Auto pause/hide when fade-out completes
            renderer.onFadeOutComplete = { [weak window, weak self] in
                DispatchQueue.main.async {
                    if self?.isVisible == false {
                        window?.orderOut(nil)
                    }
                }
            }
            
            windows.append(window)
        }
        
        logger.info("Setup \(self.windows.count) overlay windows")
    }
    
    public func show(animated: Bool = true) {
        isVisible = true
        if windows.isEmpty {
            setupOverlays()
        }
        
        for window in windows {
            window.overlayView.mtkView.isPaused = false
            window.renderer.animation.setTargetVisibility(active: true, animated: animated)
            window.orderFrontRegardless()
        }
    }
    
    public func hide(animated: Bool = true) {
        isVisible = false
        for window in windows {
            window.renderer.animation.setTargetVisibility(active: false, animated: animated)
            if !animated {
                window.overlayView.mtkView.isPaused = true
                window.orderOut(nil)
            }
        }
    }
    
    @objc private func handleScreenParametersChanged() {
        let currentScreens = NSScreen.screens
        // If display count changed, recreate
        if currentScreens.count != windows.count {
            setupOverlays()
            if isVisible {
                show(animated: false)
            }
            return
        }
        
        // Update existing displays
        for (i, screen) in currentScreens.enumerated() {
            if i < windows.count {
                windows[i].updateScreen(screen)
            }
        }
    }
}
