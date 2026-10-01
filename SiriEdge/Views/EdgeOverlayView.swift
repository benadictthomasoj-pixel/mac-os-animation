import AppKit
import MetalKit

/// Transparent container view hosting the Metal edge rendering view.
/// Passes all mouse and keyboard events straight through.
public final class EdgeOverlayView: NSView {
    public let mtkView: MTKView
    public let renderer: EdgeRenderer
    
    public init(frame: NSRect, renderer: EdgeRenderer, screen: NSScreen) {
        self.renderer = renderer
        self.mtkView = MTKView(frame: NSRect(origin: .zero, size: frame.size))
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = .clear
        
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        mtkView.wantsLayer = true
        mtkView.layer?.isOpaque = false
        mtkView.layer?.backgroundColor = .clear
        
        addSubview(mtkView)
        
        NSLayoutConstraint.activate([
            mtkView.topAnchor.constraint(equalTo: topAnchor),
            mtkView.bottomAnchor.constraint(equalTo: bottomAnchor),
            mtkView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        renderer.configure(view: mtkView, screen: screen)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Pass through all clicks, touches, and gestures to underlying windows/desktop
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
