#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// A specular band that sweeps across gold surfaces as the phone tilts, plus a slow idle drift.
// Only warm (gold) pixels pick up the highlight, so the green coin centres stay deep.
[[ stitchable ]] half4 goldSheen(float2 position, half4 color, float2 size, float2 tilt, float time, float strength) {
    if (color.a < 0.01h) { return color; }
    float2 uv = position / max(size, float2(1.0));
    float diag = uv.x * 0.72 + uv.y * 0.72;
    float centre = 0.72 + tilt.x * 0.55 + tilt.y * 0.35 + 0.10 * sin(time * 0.55);
    float band = exp(-pow((diag - centre) * 5.0, 2.0));
    float glint = exp(-pow((diag - centre - 0.16) * 16.0, 2.0)) * 0.7;
    float warm = clamp((float(color.r) - float(color.b)) * 2.4, 0.0, 1.0);
    float amount = (band * 0.5 + glint) * warm * strength;
    half3 light = half3(1.0h, 0.93h, 0.68h) * half(amount) * color.a;
    return half4(min(color.rgb + light, half3(1.0h)), color.a);
}

// Holographic foil for badges: a soft rainbow that shifts with the viewing angle.
[[ stitchable ]] half4 holoFoil(float2 position, half4 color, float2 size, float2 tilt, float time, float strength) {
    if (color.a < 0.01h) { return color; }
    float2 uv = position / max(size, float2(1.0));
    float phase = (uv.x * 1.3 + uv.y) * 2.2 + tilt.x * 3.0 + tilt.y * 2.2 + time * 0.15;
    float3 rainbow = 0.5 + 0.5 * cos(6.28318 * (phase + float3(0.0, 0.33, 0.67)));
    float sweep = exp(-pow((uv.x + uv.y - 1.0 - tilt.x * 0.8) * 3.0, 2.0));
    half3 tinted = color.rgb * half3(0.75 + rainbow * 0.5);
    half mixAmount = half(clamp(strength * (0.35 + sweep * 0.65), 0.0, 1.0));
    half3 result = mix(color.rgb, tinted, mixAmount) + half3(half(sweep * 0.12 * strength));
    return half4(min(result, half3(1.0h)), color.a);
}
