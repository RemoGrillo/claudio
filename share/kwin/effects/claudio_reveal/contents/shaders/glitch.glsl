// Glitch: the window arrives in horizontal bands that slide in from the side (from the right, Claudio's side) at
// different times, with jerks, RGB channel split and a few flashes; at the end it is clean.
// Closing does the same in reverse. Shared body: `make` turns it into glitch.frag (legacy GLSL) and glitch_core.frag (140).
uniform float uProgress;     // 0 → 1 during the animation
uniform float uForOpening;   // 1 appearing, 0 disappearing
uniform float uSeed;         // changes on every animation
uniform float uBands;        // average number of bands
uniform float uIntensity;    // amplitude of the displacement

float rnd(float x) { return fract(sin(x * 91.3458 + uSeed * 47.53) * 47453.5453); }

vec4 fetch(vec2 c) {
    if (c.x < 0.0 || c.x > 1.0 || c.y < 0.0 || c.y > 1.0) return vec4(0.0);
    return texture2D(sampler, c);   // premultiplied
}

void main() {
    vec2 uv = texcoord0;
    float p = uForOpening > 0.5 ? uProgress : 1.0 - uProgress;   // how "present" the window is

    // bands of uneven height: thin lines inside bigger blocks
    float row = floor(uv.y * uBands);
    float subrow = floor(uv.y * uBands * 3.0);
    float r1 = rnd(row), r2 = rnd(subrow + 101.0), r3 = rnd(row * 7.0 + 13.0);
    float band = r2 > 0.6 ? subrow + 500.0 : row;                // some thin lines go their own way
    float rb = rnd(band);

    // every band arrives at a different moment
    float start = rb * 0.45;
    float local = clamp((p - start) / 0.5, 0.0, 1.0);

    // stepped jerks: time is quantised, so the displacement jumps instead of gliding
    float step_ = floor(uProgress * 16.0);
    float jerk = rnd(band * 3.1 + step_ * 17.0) - 0.5;
    float rest = 1.0 - local;
    float shift = (rest * rest * (0.25 + 0.75 * r3) + jerk * 0.12 * rest) * uIntensity;
    // now and then a whole wide strip moves at once
    float strip = rnd(floor(uv.y * 4.0) + step_ * 5.0);
    if (strip > 0.85 && p < 0.95) shift += (strip - 0.85) * 0.8 * (1.0 - p) * uIntensity;

    float split = (0.003 + 0.009 * rest) * rest * uIntensity;
    vec2 c = vec2(uv.x - shift, uv.y);
    vec4 base = fetch(c);
    vec4 red = fetch(c + vec2(split, 0.0));
    vec4 blue = fetch(c - vec2(split, 0.0));
    vec4 col = vec4(red.r, base.g, blue.b, max(base.a, max(red.a, blue.a)));

    // band not arrived yet: invisible, apart from brief flickers
    float visible = local > 0.0 ? 1.0 : 0.0;
    if (local <= 0.0 && rnd(band + step_ * 3.7) > 0.93) visible = 0.6;
    // bright flash on a few bands that just arrived
    if (local > 0.0 && local < 0.35 && r1 > 0.8) col.rgb = mix(col.rgb, vec3(col.a), 0.35);
    // faint scanlines while there is noise
    col.rgb *= 1.0 - 0.15 * rest * step(0.5, fract(uv.y * 240.0));

    col *= visible;
    OUT(col);
}
