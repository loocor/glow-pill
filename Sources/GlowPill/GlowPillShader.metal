// Swift port of the movements.dev "Glow Pill" fragment shader.
//
// A black glass stadium with light pooled along its bottom edge. `position`
// and `boundingRect` arrive in SwiftUI view coordinates (origin top-left,
// y down); the math below runs in GL-style coordinates (y up) so the port
// stays line-for-line comparable with the original WebGL source.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

namespace {

float pillSdf(float2 p, float aspect) {
  float2 q = float2(max(abs(p.x) - (aspect * 0.5 - 0.5), 0.0), p.y);
  return length(q) - 0.5;
}

float hash(float n) {
  return fract(sin(n) * 43758.5453);
}

float noise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i.x + i.y * 57.0);
  float b = hash(i.x + 1.0 + i.y * 57.0);
  float c = hash(i.x + (i.y + 1.0) * 57.0);
  float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p) {
  return 0.55 * noise(p) + 0.3 * noise(p * 2.03 + 1.7)
       + 0.15 * noise(p * 4.01 + 3.1);
}

// Rotate hue in YIQ space, keeping brightness.
float3 hueShift(float3 c, float a) {
  const float3x3 toYiq = float3x3(
      0.299, 0.596, 0.211,
      0.587, -0.274, -0.523,
      0.114, -0.322, 0.312);
  const float3x3 toRgb = float3x3(
      1.0, 1.0, 1.0,
      0.956, -0.272, -1.106,
      0.621, -0.647, 1.703);
  float3 yiq = toYiq * c;
  float cs = cos(a);
  float sn = sin(a);
  yiq.yz = float2x2(cs, sn, -sn, cs) * yiq.yz;
  return max(toRgb * yiq, 0.0);
}

// A soft pool of colored light resting on the bottom edge.
float3 pool(float3 color, float x, float b, float cx, float sx, float h) {
  float dx = (x - cx) / sx;
  return color * exp(-dx * dx) * exp(-pow(max(b, 0.0) / h, 1.6));
}

// Left-to-right palette: warm -> a pale teal -> cool, for the surge.
float3 leftColor(float3 warm, float3 cool, float side) {
  return mix(warm, cool, side);
}

float3 rightColor(float3 warm, float3 cool, float side) {
  return mix(cool, warm, side);
}

float3 palette(float x, float3 warm, float3 core, float3 teal, float3 cool, float side) {
  float3 mid = mix(teal, core, 0.32);
  float3 c = mix(leftColor(warm, cool, side), mid, smoothstep(-1.15, -0.05, x));
  return mix(c, rightColor(warm, cool, side), smoothstep(0.1, 1.2, x));
}

}  // namespace

[[ stitchable ]] half4 glowPill(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float time,
    float surge,
    float warp,
    float front,
    float side,
    float glow,
    float flood,
    float3 warm,
    float3 core,
    float3 teal,
    float3 cool,
    float lights,
    float thick,
    float tint) {
  float2 res = boundingRect.zw;
  // GL-style fragment coordinate, y up.
  float2 frag = position - boundingRect.xy;
  frag.y = res.y - frag.y;
  float H = res.y;
  float aspect = res.x / H;
  float px = 1.0 / H;
  float2 p = (frag - 0.5 * res) / H;
  float t = time;

  float d = pillSdf(p, aspect);
  float inside = 1.0 - smoothstep(-1.2 * px, 0.0, d);
  float2 q = float2(max(abs(p.x) - (aspect * 0.5 - 0.5), 0.0) * sign(p.x), p.y);
  float2 n = q / max(length(q), 1e-4);
  float b = p.y + 0.5;
  float x = p.x;
  float s = surge * flood;

  float k = max(aspect / 2.92, 0.5);
  float xs = x / k;

  // Liquid surface: the pool's top edge undulates and churns.
  float wave = 0.022 * sin(xs * 2.1 + t * 0.83)
             + 0.016 * sin(xs * 3.7 - t * 1.21 + 1.3)
             + 0.010 * sin(xs * 6.3 + t * 1.7 + 4.0);
  float churn = fbm(float2(xs * 1.6 - t * 0.21, t * 0.13 + b * 1.4)) - 0.5;
  float bb = max(b - wave * (1.0 + 0.5 * s) - 0.05 * churn, 0.0);

  // Lights along the bottom edge: a cluster of nine; each drifts on its own,
  // breathes its height, and now and then spikes into a taller flare.
  float3 glowC = float3(0.0);
  for (int i = 0; i < 9; i++) {
    float fi = float(i);
    float r1 = hash(fi * 7.13 + 1.0);
    float r2 = hash(fi * 3.71 + 2.0);
    float r3 = hash(fi * 5.17 + 3.0);
    float home = -1.32 + fi * 0.33 + 0.08 * (r1 - 0.5);
    float lx = home + 0.11 * sin(t * (0.33 + 0.22 * r1) + 6.28 * r2);
    float sx = (0.25 + 0.13 * r3) * (0.85 + 0.2 * sin(t * (0.5 + 0.3 * r2) + fi));
    float breathe = 0.8 + 0.5 * (0.5 + 0.5 * sin(t * (0.55 + 0.35 * r3) + 6.28 * r1));
    float spike = pow(0.5 + 0.5 * sin(t * (0.62 + 0.4 * r2) + fi * 2.3), 10.0);
    float h = ((0.13 + 0.07 * r1) * breathe + 0.16 * spike) * thick;
    float sideW = smoothstep(0.15, 0.95, abs(home));
    float3 c = palette(home + 0.45 * (r2 - 0.5), warm, core, teal, cool, side)
             * (0.8 + 0.4 * r3);
    float a = mix(0.3, 0.34, sideW);
    glowC += lights * a * pool(c, xs, bb, lx, sx, h);
  }

  // Core: a white sun just under the edge, two lobes breathing out of step,
  // with a long faint column.
  float cx = 0.01 + 0.03 * sin(t * 0.61) + 0.02 * sin(t * 1.07 + 2.0);
  float l1 = (xs - cx - 0.06 * sin(t * 0.83)) / (0.33 + 0.03 * sin(t * 0.9));
  float l2 = (xs - cx + 0.07 * sin(t * 0.67 + 1.0)) / (0.3 + 0.04 * sin(t * 1.3 + 2.0));
  float halo = 0.62 * exp(-l1 * l1) + 0.45 * exp(-l2 * l2);
  float breath = 0.86 + 0.14 * sin(t * 1.1 + 1.5);
  float dim = (1.0 - 0.65 * s) * breath;
  glowC += lights * core * halo * dim
         * (1.4 * exp(-bb / (0.095 * dim * thick)) + 0.09 * exp(-b / 0.8));

  // The sun's crisp horizon, split into a thin rainbow at its rim.
  float2 dr = float2(0.31 + 0.05 * breath + 0.02 * sin(t * 0.7 + 1.0),
                     0.075 * dim * thick);
  float2 dc = float2(xs - cx, b + 0.03);
  float split = 0.016;
  float3 dome = float3(
      smoothstep(1.0, 0.9, length((dc - float2(split, 0.0)) / dr)),
      smoothstep(1.0, 0.9, length(dc / dr)),
      smoothstep(1.0, 0.9, length((dc + float2(split, 0.0)) / dr)));
  glowC += lights * core * dome * 1.1;

  // A slow hue drift keeps the colors alive (+/- 13 degrees).
  glowC = hueShift(glowC, 0.22 * sin(t * 0.27));

  // Surge: an arc of light climbs from the core, lighting the walls at
  // mid-height and the top as it passes, leaving a dim trough.
  float e = length(float2(xs / 2.3, b)) + 0.035 * sin(xs * 3.1 - t * 2.2);
  float behind = front - e;
  float band = exp(-pow(max(behind, 0.0) / 0.55, 2.0))
             * smoothstep(-0.16, 0.06, behind);
  float wall = exp(d / 0.16);
  float3 floodC = palette(xs + 0.12 * sin(t * 1.3), warm, core, teal, cool, side)
                * (band * (0.62 + 0.38 * wall) + 0.1 * wall);
  glowC += lights * floodC * s;

  glowC *= glow;

  // Glass: hairline rim, brightest on top, lit by the pool below.
  float rimLine = exp(-pow(d / (1.15 * px + 0.0035), 2.0));
  float top = pow(max(n.y, 0.0), 2.2);
  float rim = 0.15 + 0.66 * top;
  // The rim straddles the SDF; keep the glow contribution on the inner half
  // so the bottom light reads as contained glass, not a halo bleeding out.
  float3 rimColor = float3(rim) + glowC * 0.35 * inside;
  float sheen = 0.05 * top * exp(min(d, 0.0) / 0.022);

  // Backdrop through the lens: refract at the edges, warp while surging,
  // split channels for a chromatic rim, then darken by the glass tint.
  float w = warp * flood;
  float2 tp = p / (1.0 + 0.04 * w);
  tp += float2(0.011 * sin(p.y * 9.0 + t * 7.0),
               0.017 * sin(p.x * 4.6 - t * 6.0)) * w;
  float edge = exp(min(d, 0.0) / 0.11);
  tp -= n * edge * (0.012 + 0.05 * w);
  float ca = 0.007 * w + 0.0012 * edge;

  float2 uvGl = (tp * H + 0.5 * res) / res;
  float2 base = boundingRect.xy + float2(uvGl.x, 1.0 - uvGl.y) * res;
  float2 caView = ca * H * float2(1.0, -0.3);
  half4 backR = layer.sample(base + caView);
  half4 backG = layer.sample(base);
  half4 backB = layer.sample(base - caView);
  float3 backdropRGB = float3(backR.r, backG.g, backB.b);
  float3 col = mix(backdropRGB, float3(0.0), tint) + glowC + float3(sheen);

  // The rim adds on top, so the bottom edge reads as a lit line of glass.
  col = clamp(col, 0.0, 1.0) * inside;
  col = clamp(col + clamp(rimColor, 0.0, 1.0) * rimLine * 0.75, 0.0, 1.0);

  float alpha = max(inside, rimLine);
  return half4(half3(col), half(alpha));
}

// Text pass: the same refraction, applied to the transparent text layer.
[[ stitchable ]] half4 glowPillText(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float time,
    float warp,
    float flood) {
  float2 res = boundingRect.zw;
  float2 frag = position - boundingRect.xy;
  frag.y = res.y - frag.y;
  float H = res.y;
  float aspect = res.x / H;
  float2 p = (frag - 0.5 * res) / H;
  float t = time;

  float d = pillSdf(p, aspect);
  float2 q = float2(max(abs(p.x) - (aspect * 0.5 - 0.5), 0.0) * sign(p.x), p.y);
  float2 n = q / max(length(q), 1e-4);

  float w = warp * flood;
  float2 tp = p / (1.0 + 0.04 * w);
  tp += float2(0.011 * sin(p.y * 9.0 + t * 7.0),
               0.017 * sin(p.x * 4.6 - t * 6.0)) * w;
  float edge = exp(min(d, 0.0) / 0.11);
  tp -= n * edge * (0.012 + 0.05 * w);
  float ca = 0.007 * w + 0.0012 * edge;

  float2 uvGl = (tp * H + 0.5 * res) / res;
  float2 base = boundingRect.xy + float2(uvGl.x, 1.0 - uvGl.y) * res;
  float2 caView = ca * H * float2(1.0, -0.3);
  half4 tr = layer.sample(base + caView);
  half4 tg = layer.sample(base);
  half4 tb = layer.sample(base - caView);
  float3 textRGB = float3(tr.r, tg.g, tb.b);
  float ta = (float(tr.a) + float(tg.a) + float(tb.a)) / 3.0;
  return half4(half3(clamp(textRGB, 0.0, 1.0)), half(ta));
}
