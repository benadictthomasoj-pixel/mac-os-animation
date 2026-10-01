import AppKit
import CoreGraphics
import Foundation

/// Generates crisp, Retina-ready SiriEdge circular palm-tree menu bar icon PNG assets.
func drawPalmTreeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    
    let scale = size / 100.0
    let center = CGPoint(x: size * 0.5, y: size * 0.5)
    let radius = size * 0.46
    
    // 1. Circular Clip
    context.saveGState()
    context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
    context.clip()
    
    // 2. Vibrant Orange -> Neon Pink -> Deep Magenta Gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0),   // Vibrant Sunrise Orange
        CGColor(red: 1.0, green: 0.18, blue: 0.42, alpha: 1.0),  // Neon Siri Pink
        CGColor(red: 0.86, green: 0.0, blue: 0.40, alpha: 1.0)   // Deep Magenta
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.50, 1.0]
    
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        let startPt = CGPoint(x: size * 0.15, y: size * 0.90)
        let endPt = CGPoint(x: size * 0.85, y: size * 0.10)
        context.drawLinearGradient(gradient, start: startPt, end: endPt, options: [])
    }
    context.restoreGState()
    
    // 3. White Palm Tree Mark
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    
    // A. Trunk: Gracefully curved with organic widening at the base
    let trunkPath = CGMutablePath()
    trunkPath.move(to: CGPoint(x: 43.0 * scale, y: 14.0 * scale))
    trunkPath.addCurve(
        to: CGPoint(x: 49.5 * scale, y: 52.0 * scale),
        control1: CGPoint(x: 42.0 * scale, y: 30.0 * scale),
        control2: CGPoint(x: 45.5 * scale, y: 44.0 * scale)
    )
    trunkPath.addLine(to: CGPoint(x: 54.0 * scale, y: 52.0 * scale))
    trunkPath.addCurve(
        to: CGPoint(x: 50.5 * scale, y: 14.0 * scale),
        control1: CGPoint(x: 50.5 * scale, y: 44.0 * scale),
        control2: CGPoint(x: 48.0 * scale, y: 30.0 * scale)
    )
    trunkPath.closeSubpath()
    context.addPath(trunkPath)
    context.fillPath()
    
    // Crown center
    let cx = 51.5 * scale
    let cy = 51.5 * scale
    
    // Helper to draw a tapered, curved palm frond leaf
    func drawFrond(tip: CGPoint, ctrlUp: CGPoint, ctrlDown: CGPoint, width: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx - width * 0.5 * scale, y: cy))
        path.addQuadCurve(to: tip, control: ctrlUp)
        path.addQuadCurve(to: CGPoint(x: cx + width * 0.5 * scale, y: cy - 2.0 * scale), control: ctrlDown)
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
    }
    
    // Frond 1: Lower Left (drooping)
    drawFrond(
        tip: CGPoint(x: 18.0 * scale, y: 32.0 * scale),
        ctrlUp: CGPoint(x: 28.0 * scale, y: 52.0 * scale),
        ctrlDown: CGPoint(x: 26.0 * scale, y: 40.0 * scale),
        width: 3.5
    )
    
    // Frond 2: Upper Left (arching)
    drawFrond(
        tip: CGPoint(x: 21.0 * scale, y: 62.0 * scale),
        ctrlUp: CGPoint(x: 26.0 * scale, y: 72.0 * scale),
        ctrlDown: CGPoint(x: 37.0 * scale, y: 60.0 * scale),
        width: 4.0
    )
    
    // Frond 3: Top Left (standing upright-left)
    drawFrond(
        tip: CGPoint(x: 40.0 * scale, y: 84.0 * scale),
        ctrlUp: CGPoint(x: 38.0 * scale, y: 70.0 * scale),
        ctrlDown: CGPoint(x: 49.0 * scale, y: 72.0 * scale),
        width: 4.0
    )
    
    // Frond 4: Top Right (standing upright-right)
    drawFrond(
        tip: CGPoint(x: 63.0 * scale, y: 84.0 * scale),
        ctrlUp: CGPoint(x: 54.0 * scale, y: 72.0 * scale),
        ctrlDown: CGPoint(x: 65.0 * scale, y: 70.0 * scale),
        width: 4.0
    )
    
    // Frond 5: Upper Right (arching)
    drawFrond(
        tip: CGPoint(x: 82.0 * scale, y: 62.0 * scale),
        ctrlUp: CGPoint(x: 66.0 * scale, y: 60.0 * scale),
        ctrlDown: CGPoint(x: 77.0 * scale, y: 72.0 * scale),
        width: 4.0
    )
    
    // Frond 6: Lower Right (drooping)
    drawFrond(
        tip: CGPoint(x: 84.0 * scale, y: 32.0 * scale),
        ctrlUp: CGPoint(x: 76.0 * scale, y: 40.0 * scale),
        ctrlDown: CGPoint(x: 74.0 * scale, y: 52.0 * scale),
        width: 3.5
    )
    
    // Crown cluster / coconuts accent
    context.fillEllipse(in: CGRect(x: cx - 4.5 * scale, y: cy - 3.0 * scale, width: 9.0 * scale, height: 7.0 * scale))
    
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("❌ Failed to create PNG data for: \(path)")
        return
    }
    
    let url = URL(fileURLWithPath: path)
    try? pngData.write(to: url)
    print("✅ Generated: \(path) (\(Int(image.size.width))x\(Int(image.size.height)) pt)")
}

let fm = FileManager.default
let resDir = "SiriEdge/Resources"
try? fm.createDirectory(atPath: resDir, withIntermediateDirectories: true)

let targets: [(CGFloat, String)] = [
    (18.0, "\(resDir)/SiriEdgeMenuBarIcon.png"),
    (36.0, "\(resDir)/SiriEdgeMenuBarIcon@2x.png"),
    (54.0, "\(resDir)/SiriEdgeMenuBarIcon@3x.png"),
    (128.0, "\(resDir)/SiriEdgeMenuBarIcon_128.png")
]

for (size, path) in targets {
    let img = drawPalmTreeIcon(size: size)
    savePNG(image: img, path: path)
}

print("🎨 All SiriEdge Menu Bar Icon PNG assets created successfully!")
