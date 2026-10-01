import ScreenSaver
import Metal
import MetalKit
import SwiftUI

/// Native macOS Screen Saver view rendering the SiriEdge animated edge glow on lock screen and preview.
@objc(SiriEdgeScreenSaverView)
public class SiriEdgeScreenSaverView: ScreenSaverView {
    private var mtkView: MTKView?
    private var renderer: EdgeRenderer?
    private var configureSheetController: ScreenSaverConfigureSheetController?
    
    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        self.animationTimeInterval = 1.0 / 60.0
        self.wantsLayer = true
        setupGlow()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        self.animationTimeInterval = 1.0 / 60.0
        self.wantsLayer = true
        setupGlow()
    }
    
    deinit {
        mtkView?.isPaused = true
        mtkView?.delegate = nil
    }
    
    private func setupGlow() {
        guard let renderer = EdgeRenderer() else { return }
        self.renderer = renderer
        
        let screen = self.window?.screen ?? NSScreen.main ?? NSScreen()
        renderer.animation.setTargetVisibility(active: true, animated: false)
        
        let mtk = MTKView(frame: self.bounds)
        mtk.autoresizingMask = [.width, .height]
        mtk.isPaused = true
        renderer.configure(view: mtk, screen: screen)
        
        self.mtkView = mtk
        self.addSubview(mtk)
    }
    
    public override func startAnimation() {
        super.startAnimation()
        renderer?.animation.resetTimeline()
        mtkView?.isPaused = false
        renderer?.animation.setTargetVisibility(active: true, animated: false)
    }
    
    public override func stopAnimation() {
        super.stopAnimation()
        mtkView?.isPaused = true
    }
    
    public override func animateOneFrame() {
        // MTKView handles continuous rendering
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        mtkView?.frame = NSRect(origin: .zero, size: newSize)
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let win = window, let screen = win.screen {
            renderer?.configure(view: mtkView ?? MTKView(), screen: screen)
        } else {
            mtkView?.isPaused = true
        }
    }
    
    public override var hasConfigureSheet: Bool {
        return true
    }
    
    public override var configureSheet: NSWindow? {
        if configureSheetController == nil {
            configureSheetController = ScreenSaverConfigureSheetController()
        }
        return configureSheetController?.window
    }
}
