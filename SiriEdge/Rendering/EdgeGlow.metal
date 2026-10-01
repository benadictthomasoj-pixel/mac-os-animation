#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float2 resolution;          // Screen size in points (width, height) - 8 bytes (offset 0)
    float scaleFactor;         // Retina scale (e.g. 2.0) - 4 bytes (offset 8)
    float time;                // Elapsed time in seconds - 4 bytes (offset 12)
    
    float masterAlpha;         // Fade in / out opacity [0, 1] - 4 bytes (offset 16)
    float cornerRadius;        // Screen corner radius in points - 4 bytes (offset 20)
    float stateBrightness;     // Brightness multiplier - 4 bytes (offset 24)
    float stateSpeed;          // Speed multiplier - 4 bytes (offset 28)
    
    float stateGlowMultiplier; // Glow width multiplier - 4 bytes (offset 32)
    float coreWidth;           // Thin energy core width (e.g. 2.0 pt) - 4 bytes (offset 36)
    float innerGlowWidth;      // Inner glow width (e.g. 4.5 pt) - 4 bytes (offset 40)
    float wakeWidth;           // Wake trail width (e.g. 6.0 pt) - 4 bytes (offset 44)
    
    float bloomRadius;         // Ambient halo radius (e.g. 12.0 pt) - 4 bytes (offset 48)
    float baseIntensity;       // Base perimeter glow intensity - 4 bytes (offset 52)
    float coreIntensity;       // Core light intensity - 4 bytes (offset 56)
    float wakeIntensity;       // Trailing wake intensity - 4 bytes (offset 60)
    
    float bloomIntensity;      // Halo bloom intensity - 4 bytes (offset 64)
    float maxGlowExtent;       // Maximum inward glow distance (e.g. 20.0 pt) - 4 bytes (offset 68)
    float forwardPushLength;   // Forward light reach along perimeter - 4 bytes (offset 72)
    float backwardWakeLength;  // Trailing wake reach along perimeter - 4 bytes (offset 76)
    
    float vibrancy;            // Color saturation / vibrancy - 4 bytes (offset 80)
    float overallOpacity;      // User transparency setting - 4 bytes (offset 84)
    float pad0;                // Padding - 4 bytes (offset 88)
    float pad1;                // Padding - 4 bytes (offset 92)
    
    float4 pulsePositions;     // 4 Light pulse locations along perimeter u in [0, 1) - 16 bytes (offset 96)
    float4 pulseIntensities;   // Intensities of light pulses - 16 bytes (offset 112)
};

// MARK: - Vertex Shader

vertex VertexOut edgeVertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 grid = float2((vertexID << 1) & 2, vertexID & 2);
    out.position = float4(grid * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    out.uv = grid;
    return out;
}

// MARK: - Color Palette

static float3 sampleSiriPalette(float t, float vibrancy) {
    float normT = fract(t);
    float scaled = normT * 6.0;
    int idx = int(scaled);
    float f = fract(scaled);
    f = f * f * (3.0 - 2.0 * f);
    
    const float3 c0 = float3(0.00, 0.85, 1.00); // Electric Cyan
    const float3 c1 = float3(0.12, 0.50, 1.00); // Electric Blue
    const float3 c2 = float3(0.48, 0.18, 0.98); // Violet
    const float3 c3 = float3(0.70, 0.14, 0.95); // Purple
    const float3 c4 = float3(0.96, 0.12, 0.72); // Magenta
    const float3 c5 = float3(1.00, 0.38, 0.80); // Pink
    
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

// Signed circular distance along perimeter [-0.5, 0.5]
static inline float signedCircularDist(float targetU, float pulsePos) {
    return fract(targetU - pulsePos + 0.5) - 0.5;
}

// MARK: - Continuous Display Perimeter Geometry

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
    
    // Signed distance to physical screen boundary (2D rounded rectangle)
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
    
    // Arc length s along complete continuous perimeter loop:
    // Top-Left (r, 0) -> Top-Right -> Bottom-Right -> Bottom-Left -> Top-Left
    float s = 0.0;
    
    if (p.x < r && p.y < r) {
        // Top-Left Corner
        float angle = atan2(r - p.x, r - p.y);
        s = 2.0 * L_top + 3.0 * L_corner + 2.0 * L_right + angle * r;
    } else if (p.x > W - r && p.y < r) {
        // Top-Right Corner
        float angle = atan2(p.x - (W - r), r - p.y);
        s = L_top + angle * r;
    } else if (p.x > W - r && p.y > H - r) {
        // Bottom-Right Corner
        float angle = atan2(p.y - (H - r), p.x - (W - r));
        s = L_top + L_corner + L_right + angle * r;
    } else if (p.x < r && p.y > H - r) {
        // Bottom-Left Corner
        float angle = atan2(r - p.x, p.y - (H - r));
        s = 2.0 * L_top + 2.0 * L_corner + L_right + angle * r;
    } else if (p.x >= r && p.x <= W - r && p.y <= center.y) {
        // Top Edge (0 -> W)
        s = p.x - r;
    } else if (p.x >= r && p.x <= W - r && p.y > center.y) {
        // Bottom Edge (W+H -> 2W+H)
        s = L_top + 2.0 * L_corner + L_right + (W - r - p.x);
    } else if (p.y >= r && p.y <= H - r && p.x >= center.x) {
        // Right Edge (W -> W+H)
        s = L_top + L_corner + (p.y - r);
    } else {
        // Left Edge (2W+H -> 2W+2H)
        s = 2.0 * L_top + 3.0 * L_corner + L_right + (H - r - p.y);
    }
    
    outU = fract(s / max(totalLength, 1.0));
}

// MARK: - Fragment Shader

fragment float4 edgeFragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms &u [[buffer(0)]]
) {
    if (u.masterAlpha <= 0.001) {
        discard_fragment();
    }
    
    float2 p = in.uv * u.resolution;
    
    // TIGHT BOUNDARY REJECT: Discard center of screen immediately
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
    
    // 1. Base Thin Perimeter Line (Luminous, sharp boundary)
    float baseLineCore = exp(-pow(d / max(coreW, 0.5), 1.8)) * u.baseIntensity;
    float baseLineGlow = exp(-pow(d / max(innerW, 1.0), 1.5)) * (u.baseIntensity * 0.35);
    float baseWeight = baseLineCore + baseLineGlow;
    float3 baseColor = sampleSiriPalette(perimeterU + u.time * 0.03 * u.stateSpeed, u.vibrancy * 0.90);
    
    float3 colorAccum = baseColor * baseWeight;
    float alphaAccum = baseWeight;
    
    // 2. Continuous Traveling Light Pulses (Thinking / Chasing Flow)
    for (int i = 0; i < 4; ++i) {
        float pulsePos = u.pulsePositions[i];
        float pulseInt = u.pulseIntensities[i];
        if (pulseInt <= 0.01) continue;
        
        float sDist = signedCircularDist(perimeterU, pulsePos);
        float absDist = abs(sDist);
        if (absDist > 0.40) continue;
        
        // A. Crisp moving energy core point
        float coreLongitudinal = exp(-pow(absDist / 0.038, 2.0));
        float coreTransverse = exp(-pow(d / max(coreW, 0.5), 1.8));
        float coreWeight = coreLongitudinal * coreTransverse * u.coreIntensity * pulseInt;
        
        float3 pColor = sampleSiriPalette(pulsePos + 0.05, u.vibrancy);
        float coreGlint = coreLongitudinal * exp(-pow(d / max(coreW * 0.55, 0.35), 2.2)) * 0.20;
        float3 lightPointColor = mix(pColor, float3(1.0, 1.0, 1.0), coreGlint);
        
        colorAccum += lightPointColor * coreWeight;
        alphaAccum += coreWeight;
        
        // B. Directional Energy Wake (Forward push + trailing wake)
        float wakeLongitudinal = (sDist >= 0.0)
            ? exp(-pow(sDist / max(u.forwardPushLength, 0.01), 2.0))
            : exp(-pow((-sDist) / max(u.backwardWakeLength, 0.01), 1.5));
            
        float wakeTransverse = exp(-pow(d / max(wakeW, 0.8), 1.4));
        float wakeWeight = wakeLongitudinal * wakeTransverse * u.wakeIntensity * pulseInt;
        float3 wakeColor = sampleSiriPalette(pulsePos + sDist * 0.25, u.vibrancy * 0.95);
        
        colorAccum += wakeColor * wakeWeight;
        alphaAccum += wakeWeight;
        
        // C. Subtle ambient halo bloom around traveling light
        float bloomLong = exp(-pow(absDist / 0.14, 2.0));
        float bloomTrans = exp(-pow(d / max(bloomR, 1.0), 1.25));
        float bloomWeight = bloomLong * bloomTrans * u.bloomIntensity * pulseInt;
        
        colorAccum += pColor * bloomWeight;
        alphaAccum += bloomWeight;
    }
    
    float3 finalRGB = colorAccum / max(alphaAccum, 0.001);
    
    // Premultiplied alpha calculation with user transparency and brightness
    float alpha = clamp(alphaAccum * u.stateBrightness * u.masterAlpha * u.overallOpacity, 0.0, 1.0);
    
    if (alpha <= 0.002) {
        discard_fragment();
    }
    
    return float4(finalRGB * alpha, alpha);
}
