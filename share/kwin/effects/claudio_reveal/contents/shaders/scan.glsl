// Scan: a bright cyan line sweeps across the sidebar from right to left. Ahead of the line the window is a blurred
// cyan "hologram" with a thin grid, lighting up as the line gets closer; behind the line it is sharp again.
// Closing: the line goes back and leaves nothing behind.
uniform float uProgress;
uniform float uForOpening;
uniform float uSeed;
uniform float uIntensity;
uniform int textureWidth;
uniform int textureHeight;

void main() {
    vec2 uv = texcoord0;
    vec2 size = vec2(float(textureWidth), float(textureHeight));
    vec2 px = uv * size;
    float p = uForOpening > 0.5 ? uProgress : 1.0 - uProgress;
    float e = p * p * (3.0 - 2.0 * p);   // soft at the start and at the end

    float front = 1.25 - e * 1.5;                     // from beyond the right edge to beyond the left edge
    float d = uv.x - front;                           // > 0: already scanned
    float trail = 0.35;                               // width of the holographic zone ahead of the line

    // hologram ahead of the line: fades in within "trail"
    float holo = clamp(1.0 + d / trail, 0.0, 1.0) * step(d, 0.0);
    float sharp = smoothstep(0.0, 0.06, d);

    // 5x5 blur, stronger far from the line
    float radius = (2.0 + 10.0 * clamp(-d / trail, 0.0, 1.0)) * uIntensity;
    vec4 blurred = vec4(0.0);
    for (int i = -2; i <= 2; i++)
        for (int j = -2; j <= 2; j++)
            blurred += texture2D(sampler, uv + vec2(float(i), float(j)) * radius / size);
    blurred /= 25.0;

    vec3 cyan = vec3(0.25, 0.85, 1.0);
    float lum = dot(blurred.rgb, vec3(0.3, 0.6, 0.1));
    vec4 hologram = vec4(mix(blurred.rgb, cyan * (0.25 + lum * 1.4) * blurred.a, 0.7), blurred.a);
    // grid and scrolling lines
    float grid = max(step(0.94, fract(px.x / 22.0)), step(0.94, fract(px.y / 22.0)));
    float lines = 0.5 + 0.5 * sin(px.y * 1.3 - uProgress * 40.0);
    hologram.rgb += cyan * (grid * 0.18 + lines * 0.05) * max(hologram.a, 0.3);
    hologram.a = max(hologram.a, grid * 0.12);
    hologram *= holo * (0.55 + 0.45 * holo);

    vec4 col = mix(hologram, texture2D(sampler, uv), sharp);

    // the line: white-cyan core with a halo, slight flicker
    float flicker = 0.85 + 0.15 * sin(uProgress * 90.0 + px.y * 0.05 + uSeed * 6.28);
    float line = exp(-abs(d) * size.x / 2.5) + 0.5 * exp(-abs(d) * size.x / 18.0);
    line *= flicker * step(-0.02, front) * step(front, 1.02);
    vec3 light = mix(cyan, vec3(1.0), 0.5) * line * uIntensity;
    col.rgb += light;
    col.a = max(col.a, clamp(line * 0.8, 0.0, 1.0));
    OUT(col);
}
