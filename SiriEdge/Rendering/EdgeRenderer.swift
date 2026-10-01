import Foundation
import Metal
import MetalKit
import QuartzCore
import os.log

private let logger = Logger(subsystem: "com.antigravity.SiriEdge", category: "EdgeRenderer")

/// Metal-accelerated perimeter glow renderer for SiriEdge.
/// Uses triple-buffered uniforms, zero-allocation per-frame updates, and display-synchronized cadence.
public final class EdgeRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    
    // Triple-buffered uniforms
    private static let maxBuffersInFlight = 3
    private var uniformBuffers: [MTLBuffer] = []
    private var currentBufferIndex: Int = 0
    private let inFlightSemaphore = DispatchSemaphore(value: EdgeRenderer.maxBuffersInFlight)
    
    public var cachedSize: CGSize = CGSize(width: 1920, height: 1080)
    public var cachedScale: CGFloat = 2.0
    
    public let animation: EdgeAnimation
    
    // Telemetry & metrics
    public private(set) var currentFPS: Double = 30.0
    public private(set) var targetFPS: Int = 30
    public private(set) var displayRefreshHz: Double = 60.0
    public private(set) var drawCallsPerSecond: Int = 0
    public private(set) var currentFrameTimeMs: Double = 0.0
    
    private var frameCount: Int = 0
    private var lastFPSUpdateTime: CFTimeInterval = 0.0
    
    public var onFadeOutComplete: (() -> Void)?
    
    public init?(device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            logger.error("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = queue
        self.animation = EdgeAnimation()
        super.init()
        
        setupBuffers()
        setupPipeline()
        self.lastFPSUpdateTime = CACurrentMediaTime()
        self.targetFPS = EdgeSettings.shared.effectiveTargetFPS
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: EdgeSettings.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleSettingsChanged() {
        self.targetFPS = EdgeSettings.shared.effectiveTargetFPS
        self.animation.reloadConfig()
    }
    
    private func setupBuffers() {
        let bufferSize = MemoryLayout<EdgeUniforms>.stride
        for _ in 0..<EdgeRenderer.maxBuffersInFlight {
            guard let buf = device.makeBuffer(length: bufferSize, options: [.storageModeShared]) else {
                fatalError("Failed to allocate Metal uniform buffer")
            }
            uniformBuffers.append(buf)
        }
    }
    
    private func setupPipeline() {
        do {
            let library: MTLLibrary
            if let defaultLib = try? device.makeDefaultLibrary(bundle: Bundle.main) {
                library = defaultLib
            } else if let resourceUrl = Bundle.main.url(forResource: "EdgeGlow", withExtension: "metal"),
                      let src = try? String(contentsOf: resourceUrl) {
                library = try device.makeLibrary(source: src, options: nil)
            } else {
                library = try device.makeLibrary(source: embeddedShaderSource, options: nil)
            }
            
            guard let vertexFunction = library.makeFunction(name: "edgeVertexShader"),
                  let fragmentFunction = library.makeFunction(name: "edgeFragmentShader") else {
                logger.error("Failed to find shader functions in Metal library")
                return
            }
            
            let desc = MTLRenderPipelineDescriptor()
            desc.label = "SiriEdgePipeline"
            desc.vertexFunction = vertexFunction
            desc.fragmentFunction = fragmentFunction
            
            if let colorAttachment = desc.colorAttachments[0] {
                colorAttachment.pixelFormat = .bgra8Unorm
                colorAttachment.isBlendingEnabled = true
                colorAttachment.rgbBlendOperation = .add
                colorAttachment.alphaBlendOperation = .add
                colorAttachment.sourceRGBBlendFactor = .one
                colorAttachment.sourceAlphaBlendFactor = .one
                colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            
            self.pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            logger.error("Pipeline creation failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let scale = view.window?.backingScaleFactor ?? 2.0
        self.cachedSize = CGSize(width: size.width / scale, height: size.height / scale)
        self.cachedScale = scale
    }
    
    public func draw(in view: MTKView) {
        let frameStart = CACurrentMediaTime()
        
        // If fully faded out, pause the view to consume 0% GPU
        if animation.isFullyFadedOut {
            view.isPaused = true
            onFadeOutComplete?()
            return
        }
        
        _ = inFlightSemaphore.wait(timeout: .distantFuture)
        
        guard let pipelineState = pipelineState,
              let renderPassDesc = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            inFlightSemaphore.signal()
            return
        }
        
        let buffer = uniformBuffers[currentBufferIndex]
        currentBufferIndex = (currentBufferIndex + 1) % EdgeRenderer.maxBuffersInFlight
        
        let ptr = buffer.contents().bindMemory(to: EdgeUniforms.self, capacity: 1)
        _ = animation.updateDirect(size: cachedSize, scaleFactor: cachedScale, into: ptr)
        
        renderPassDesc.colorAttachments[0].loadAction = .clear
        renderPassDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            inFlightSemaphore.signal()
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }
        commandBuffer.commit()
        
        // Metrics calculation
        frameCount += 1
        let now = CACurrentMediaTime()
        let elapsed = now - lastFPSUpdateTime
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            drawCallsPerSecond = frameCount
            frameCount = 0
            lastFPSUpdateTime = now
        }
        currentFrameTimeMs = (now - frameStart) * 1000.0
    }
    
    public func configure(view: MTKView, screen: NSScreen) {
        view.device = device
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        
        // Refresh rate & target FPS
        if let mode = CGDisplayCopyDisplayMode(screen.displayID ?? CGMainDisplayID()) {
            let hz = mode.refreshRate
            self.displayRefreshHz = hz > 0 ? hz : 60.0
        }
        
        let target = EdgeSettings.shared.effectiveTargetFPS
        self.targetFPS = target
        view.preferredFramesPerSecond = target
        
        let scale = screen.backingScaleFactor
        self.cachedSize = screen.frame.size
        self.cachedScale = scale
        view.drawableSize = CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale)
    }
}

// Embedded shader source fallback for guaranteed zero-dependency compilation
private let embeddedShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float2 resolution;
    float scaleFactor;
    float time;
    float masterAlpha;
    float cornerRadius;
    float stateBrightness;
    float stateSpeed;
    float stateGlowMultiplier;
    float coreWidth;
    float innerGlowWidth;
    float wakeWidth;
    float bloomRadius;
    float baseIntensity;
    float coreIntensity;
    float wakeIntensity;
    float bloomIntensity;
    float maxGlowExtent;
    float forwardPushLength;
    float backwardWakeLength;
    float vibrancy;
    float overallOpacity;
    float pad0;
    float pad1;
    float4 pulsePositions;
    float4 pulseIntensities;
};

vertex VertexOut edgeVertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 grid = float2((vertexID << 1) & 2, vertexID & 2);
    out.position = float4(grid * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    out.uv = grid;
    return out;
}

static float3 sampleSiriPalette(float t, float vibrancy) {
    float normT = fract(t);
    float scaled = normT * 6.0;
    int idx = int(scaled);
    float f = fract(scaled);
    f = f * f * (3.0 - 2.0 * f);
    
    const float3 c0 = float3(0.00, 0.85, 1.00);
    const float3 c1 = float3(0.12, 0.50, 1.00);
    const float3 c2 = float3(0.48, 0.18, 0.98);
    const float3 c3 = float3(0.70, 0.14, 0.95);
    const float3 c4 = float3(0.96, 0.12, 0.72);
    const float3 c5 = float3(1.00, 0.38, 0.80);
    
    float3 col;
    switch (idx) {
        case 0: col = mix(c0, c1, f); break;
        case 1: col = mix(c1, c2, f); break;
        case 2: col = mix(c2, c3, f); break;
        case 3: col = mix(c3, c4, f); break;
        case 4: col = mix(c4, c5, f); break;
        default: col = mix(c5, c0, f); break;
    }
    float lum = dot(col, float3(0.299, 0.587, 0.114));
    return clamp(mix(float3(lum), col, vibrancy), 0.0, 1.0);
}

static inline float signedCircularDist(float targetU, float pulsePos) {
    return fract(targetU - pulsePos + 0.5) - 0.5;
}

static void computePerimeterCoordAndDistance(
    float2 p,
    float2 size,
    float r,
    thread float &outDist,
    thread float &outU
) {
    float W = size.x;
    float H = size.y;
    r = clamp(r, 0.0, min(W, H) * 0.5);
    
    float L_top = max(0.0, W - 2.0 * r);
    float L_right = max(0.0, H - 2.0 * r);
    float L_corner = 0.5 * M_PI_F * r;
    float totalLength = 2.0 * L_top + 2.0 * L_right + 4.0 * L_corner;
    
    float2 halfSize = float2(W * 0.5 - r, H * 0.5 - r);
    float2 center = float2(W * 0.5, H * 0.5);
    float2 q = abs(p - center) - halfSize;
    
    if (q.x <= 0.0 && q.y <= 0.0) {
        outDist = min(-q.x, -q.y) + r;
    } else if (q.x > 0.0 && q.y <= 0.0) {
        outDist = r - q.x;
    } else if (q.x <= 0.0 && q.y > 0.0) {
        outDist = r - q.y;
    } else {
        outDist = r - length(q);
    }
    
    float s = 0.0;
    if (p.x < r && p.y < r) {
        float angle = atan2(r - p.x, r - p.y);
        s = 2.0 * L_top + 3.0 * L_corner + 2.0 * L_right + angle * r;
    } else if (p.x > W - r && p.y < r) {
        float angle = atan2(p.x - (W - r), r - p.y);
        s = L_top + angle * r;
    } else if (p.x > W - r && p.y > H - r) {
        float angle = atan2(p.y - (H - r), p.x - (W - r));
        s = L_top + L_corner + L_right + angle * r;
    } else if (p.x < r && p.y > H - r) {
        float angle = atan2(r - p.x, p.y - (H - r));
        s = 2.0 * L_top + 2.0 * L_corner + L_right + angle * r;
    } else if (p.x >= r && p.x <= W - r && p.y <= center.y) {
        s = p.x - r;
    } else if (p.x >= r && p.x <= W - r && p.y > center.y) {
        s = L_top + 2.0 * L_corner + L_right + (W - r - p.x);
    } else if (p.y >= r && p.y <= H - r && p.x >= center.x) {
        s = L_top + L_corner + (p.y - r);
    } else {
        s = 2.0 * L_top + 3.0 * L_corner + L_right + (H - r - p.y);
    }
    outU = fract(s / max(totalLength, 1.0));
}

fragment float4 edgeFragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms &u [[buffer(0)]]
) {
    if (u.masterAlpha <= 0.001) {
        discard_fragment();
    }
    
    float2 p = in.uv * u.resolution;
    float approxDistFromEdge = min(min(p.x, u.resolution.x - p.x), min(p.y, u.resolution.y - p.y));
    float maxExtent = u.maxGlowExtent * u.stateGlowMultiplier;
    
    if (approxDistFromEdge > maxExtent + u.cornerRadius + 4.0) {
        discard_fragment();
    }
    
    float inwardDist = 0.0;
    float perimeterU = 0.0;
    computePerimeterCoordAndDistance(p, u.resolution, u.cornerRadius, inwardDist, perimeterU);
    
    if (inwardDist < -0.5 || inwardDist > maxExtent) {
        discard_fragment();
    }
    
    float d = max(0.0, inwardDist);
    float coreW = u.coreWidth;
    float innerW = u.innerGlowWidth * u.stateGlowMultiplier;
    float wakeW = u.wakeWidth * u.stateGlowMultiplier;
    float bloomR = u.bloomRadius * u.stateGlowMultiplier;
    
    float baseLineCore = exp(-pow(d / max(coreW, 0.5), 1.8)) * u.baseIntensity;
    float baseLineGlow = exp(-pow(d / max(innerW, 1.0), 1.5)) * (u.baseIntensity * 0.35);
    float baseWeight = baseLineCore + baseLineGlow;
    float3 baseColor = sampleSiriPalette(perimeterU + u.time * 0.03 * u.stateSpeed, u.vibrancy * 0.90);
    
    float3 colorAccum = baseColor * baseWeight;
    float alphaAccum = baseWeight;
    
    for (int i = 0; i < 4; ++i) {
        float pulsePos = u.pulsePositions[i];
        float pulseInt = u.pulseIntensities[i];
        if (pulseInt <= 0.01) continue;
        
        float sDist = signedCircularDist(perimeterU, pulsePos);
        float absDist = abs(sDist);
        if (absDist > 0.40) continue;
        
        float coreLongitudinal = exp(-pow(absDist / 0.038, 2.0));
        float coreTransverse = exp(-pow(d / max(coreW, 0.5), 1.8));
        float coreWeight = coreLongitudinal * coreTransverse * u.coreIntensity * pulseInt;
        
        float3 pColor = sampleSiriPalette(pulsePos + 0.05, u.vibrancy);
        float coreGlint = coreLongitudinal * exp(-pow(d / max(coreW * 0.55, 0.35), 2.2)) * 0.20;
        float3 lightPointColor = mix(pColor, float3(1.0, 1.0, 1.0), coreGlint);
        
        colorAccum += lightPointColor * coreWeight;
        alphaAccum += coreWeight;
        
        float wakeLongitudinal = (sDist >= 0.0)
            ? exp(-pow(sDist / max(u.forwardPushLength, 0.01), 2.0))
            : exp(-pow((-sDist) / max(u.backwardWakeLength, 0.01), 1.5));
            
        float wakeTransverse = exp(-pow(d / max(wakeW, 0.8), 1.4));
        float wakeWeight = wakeLongitudinal * wakeTransverse * u.wakeIntensity * pulseInt;
        float3 wakeColor = sampleSiriPalette(pulsePos + sDist * 0.25, u.vibrancy * 0.95);
        
        colorAccum += wakeColor * wakeWeight;
        alphaAccum += wakeWeight;
        
        float bloomLong = exp(-pow(absDist / 0.14, 2.0));
        float bloomTrans = exp(-pow(d / max(bloomR, 1.0), 1.25));
        float bloomWeight = bloomLong * bloomTrans * u.bloomIntensity * pulseInt;
        
        colorAccum += pColor * bloomWeight;
        alphaAccum += bloomWeight;
    }
    
    float3 finalRGB = colorAccum / max(alphaAccum, 0.001);
    float alpha = clamp(alphaAccum * u.stateBrightness * u.masterAlpha * u.overallOpacity, 0.0, 1.0);
    
    if (alpha <= 0.002) {
        discard_fragment();
    }
    return float4(finalRGB * alpha, alpha);
}
"""

extension NSScreen {
    public var displayID: CGDirectDisplayID? {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(id.uint32Value)
    }
}
