#version 440
// Glow around a rounded rectangle (the sidebar): nothing inside, fading out towards the outside.
// Colours (from colors.conf): 2-4 hues blending along the edge, with an optional highlight slowly sweeping around.
// `make` compiles it to glow.frag.qsb.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // seconds
    vec2 area;        // size of the glow window (logical pixels)
    vec4 box;         // sidebar: x, y, width, height (inside the glow window)
    float radius;
    vec4 color1;      // colours from colors.conf, read in Glow.qml
    vec4 color2;
    vec4 color3;
    vec4 color4;
    vec4 highlight;   // alpha 0 = no highlight
    float numColors;  // 2, 3 or 4
    vec4 hole;        // window that must stay above the glow (KRunner): x, y, width, height; width 0 = none
};

vec3 hue(float i) {
    if (i < 0.5) return color1.rgb;
    if (i < 1.5) return color2.rgb;
    if (i < 2.5) return color3.rgb;
    return color4.rgb;
}

float sdBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * area;
    vec2 c = box.xy + box.zw * 0.5;
    float d = sdBox(p - c, box.zw * 0.5, radius);
    if (d <= 0.0) { fragColor = vec4(0.0); return; }

    const float PI2 = 6.2831853;
    // position along the visible edge (0-1): top from right to left, then the left side, then the bottom;
    // the right side is against the edge of the screen and never visible. Continuous through the corners too.
    vec2 lo = box.xy;
    vec2 hi = box.xy + box.zw;
    vec2 q = clamp(p, lo, hi);
    float s;
    if (p.y < lo.y && p.x > lo.x) s = hi.x - q.x;
    else if (p.y > hi.y && p.x > lo.x) s = box.z + box.w + (q.x - lo.x);
    else s = box.z + (q.y - lo.y);
    float u = s / (2.0 * box.z + box.w);

    // organic blend: every colour is a wide patch along the edge overlapping its neighbours; the edge is "stretched"
    // by slow waves and every patch drifts at its own pace, so there are no hard sections
    float n = max(numColors, 2.0);
    float phase = u * 3.2 + time * 0.04
                + 0.10 * sin(PI2 * (u * 2.0 + time * 0.027))
                + 0.06 * sin(PI2 * (u * 3.0 - time * 0.019) + 1.3);
    vec3 sum = vec3(0.0);
    float weights = 0.0;
    float vivid = 0.0;
    for (int k = 0; k < 4; k++) {
        float fk = float(k);
        if (fk >= n) break;
        float drift = 0.10 * sin(time * (0.11 + 0.04 * fk) + fk * 1.9);
        float w = pow(0.5 + 0.5 * cos(PI2 * (phase - fk / n + drift)), 2.4) + 0.02;
        vec3 ck = hue(fk);
        sum += ck * w;
        vivid += max(ck.r, max(ck.g, ck.b)) * w;
        weights += w;
    }
    vec3 col = sum / weights;
    // the average of distant colours (e.g. light blue + orange) tends to grey: give the brightness back
    col *= (vivid / weights) / max(max(col.r, max(col.g, col.b)), 0.001);
    float sheen = pow(0.5 + 0.5 * sin(PI2 * (u - time * 0.05)), 14.0) * highlight.a;
    col = mix(col, highlight.rgb, sheen * 0.75);

    // thin, varying along the edge and over time (0.65-1.15): in places it reaches a bit further
    float wave = 0.6 * sin(PI2 * (u * 3.0 + time * 0.021)) + 0.4 * sin(PI2 * (u * 5.0 - time * 0.033));
    float reach = 0.9 + 0.25 * wave;
    float dd = d / reach;
    float breath = 0.85 + 0.15 * sin(time * 1.3);
    float a = (0.46 * exp(-dd / 3.2) + 0.15 * exp(-dd / 8.0)) * breath * (1.0 + sheen * 0.6);
    // fade to zero before the edge of the window (margin = box.x), so no step shows
    a *= 1.0 - smoothstep(box.x * 0.55, box.x * 0.95, d);
    a = clamp(a, 0.0, 0.75);
    // no glow over KRunner: there the glow "goes under" its window
    if (hole.z > 0.0)
        a *= smoothstep(-0.5, 0.5, sdBox(p - hole.xy - hole.zw * 0.5, hole.zw * 0.5, 8.0));
    fragColor = vec4(col * a, a) * qt_Opacity;
}
