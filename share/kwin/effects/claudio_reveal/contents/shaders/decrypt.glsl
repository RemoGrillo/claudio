// Decrypt: the window shows up as a grid of green characters that keep changing (like a terminal decrypting), then
// every cell "resolves" into the real content, top to bottom along a ragged front, with a green flash as it passes.
// Closing: the content turns back into characters and fades out from the bottom.
uniform float uProgress;
uniform float uForOpening;
uniform float uSeed;
uniform float uIntensity;
uniform int textureWidth;
uniform int textureHeight;

float rnd(vec2 v) { return fract(sin(dot(v + uSeed * 13.17, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 uv = texcoord0;
    vec2 px = uv * vec2(float(textureWidth), float(textureHeight));
    float p = uForOpening > 0.5 ? uProgress : 1.0 - uProgress;

    vec2 size = vec2(9.0, 16.0);                      // one cell = one character
    vec2 cell = floor(px / size);
    vec2 rows = vec2(float(textureWidth), float(textureHeight)) / size;
    vec2 inside = fract(px / size);

    // front: top to bottom, ragged per column and per cell
    float yrel = cell.y / max(rows.y, 1.0);
    float delay = yrel * 0.55 + rnd(vec2(cell.x, 3.0)) * 0.12 + rnd(cell) * 0.18;
    float shown = clamp((p - delay * 0.85) / 0.12, 0.0, 1.0);             // the cell appears as a character
    float resolved = clamp((p - delay * 0.85 - 0.14) / 0.12, 0.0, 1.0);   // then becomes the real content

    vec4 real = texture2D(sampler, uv);
    // the character: a random 5x7 matrix changing in steps; brightness from the (blurred) cell content
    vec2 centre = (cell + 0.5) * size / vec2(float(textureWidth), float(textureHeight));
    vec4 avg = (texture2D(sampler, centre) + texture2D(sampler, centre + vec2(size.x, 0.0) / float(textureWidth))
              + texture2D(sampler, centre - vec2(0.0, size.y) / float(textureHeight))) / 3.0;
    vec2 dot_ = floor(inside * vec2(7.0, 9.0));
    float margin = (dot_.x < 1.0 || dot_.x > 5.0 || dot_.y < 1.0 || dot_.y > 7.0) ? 0.0 : 1.0;
    float tick = floor(uProgress * 30.0 + rnd(cell) * 8.0);
    float lit = step(0.5, rnd(cell * 7.0 + floor(dot_) * 0.37 + tick)) * margin;
    float lum = 0.25 + 0.75 * clamp(dot(avg.rgb, vec3(0.3, 0.6, 0.1)) * 2.0, 0.0, 1.0);
    vec3 green = vec3(0.22, 1.0, 0.53);
    float a_char = lit * shown * (1.0 - resolved) * lum * (0.55 + 0.45 * uIntensity);
    vec4 character = vec4(green * a_char, a_char);
    // cell background while it is still code: a dark greenish veil, so the sidebar "takes shape"
    float veil = shown * (1.0 - resolved) * 0.35 * max(real.a, 0.4);
    vec4 back = vec4(vec3(0.0, 0.06, 0.03) * veil, veil);

    // flash when the cell resolves
    float flash = resolved * (1.0 - resolved) * 4.0 * 0.6;
    vec4 col = real * resolved + (character + back * (1.0 - lit)) * (1.0 - resolved);
    col.rgb += green * flash * col.a * uIntensity;
    // scanlines until everything is resolved
    col.rgb *= 1.0 - 0.12 * (1.0 - p) * step(0.5, fract(px.y / 3.0));
    OUT(col);
}
