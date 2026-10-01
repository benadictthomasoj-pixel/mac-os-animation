import AppKit

/// Borderless, non-activating, transparent window strictly covering the physical display boundary.
/// Floats above all Spaces and Fullscreen apps without capturing clicks or stealing focus.
public final class OverlayWindow: NSPanel {
    public let overlayView: EdgeOverlayView
    public private(set) var screenTarget: NSScreen
    public let renderer: EdgeRenderer
    
    public init(screen: NSScreen, renderer: EdgeRenderer) {
        self.screenTarget = screen
        self.renderer = renderer
        self.overlayView = EdgeOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size), renderer: renderer, screen: screen)
        
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
    }
    
    private func configureWindow() {
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.sharingType = .none
        self.animationBehavior = .none
        
        self.level = .screenSaver
        self.ignoresMouseEvents = true
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.isRestorable = false
        
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.contentView = overlayView
        
        setFrame(screenTarget.frame, display: false, animate: false)
    }
    
    /// Update display geometry if display resolution or arrangement changes
    public func updateScreen(_ newScreen: NSScreen) {
        self.screenTarget = newScreen
        if self.frame != newScreen.frame {
            setFrame(newScreen.frame, display: true, animate: false)
            overlayView.frame = NSRect(origin: .zero, size: newScreen.frame.size)
            renderer.configure(view: overlayView.mtkView, screen: newScreen)
        }
    }
    
    /// Strictly return physical screen frame to prevent macOS from clipping to visibleFrame (below menu bar)
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return screenTarget.frame
    }
    
    public override var canBecomeKey: Bool {
        return false
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
}
