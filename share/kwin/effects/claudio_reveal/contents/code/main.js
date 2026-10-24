// Reveal animation of Claudio (Ghostty quick terminal, instance io.github.remogrillo.claudio).
// KWin's own slide is taken away from that instance (noslide.so in LD_PRELOAD): the effect is chosen here.
// Settings in kwinrc [Effect-claudio_reveal]:
//   Effect = glitch | decrypt | scan | slide | none
//   Speed = multiplier (2 = twice as fast) of each effect's base durations
//   DurationIn, DurationOut = fixed ms (0 = automatic: base duration / Speed)
//   Bands (glitch only), Intensity (glitch, decrypt, scan)
// Change them with `claudio-effect`, from the tray menu or in System Settings → Desktop Effects.
"use strict";

// base durations [in, out] in ms
const DURATIONS = {
    glitch: [300, 220],
    decrypt: [650, 380],
    scan: [520, 360],
    slide: [220, 180]
};
const SHADERS = ["glitch", "decrypt", "scan"];

// a uniform the shader does not use is optimised away by the compiler and setUniform throws: that must not stop the animation
function uniform(shader, name, value) {
    try { effect.setUniform(shader, name, value); } catch (e) { console.log("claudio_reveal:", name, e); }
}

class ClaudioReveal {
    constructor() {
        this.shader = {};
        for (const name of SHADERS) this.shader[name] = effect.addFragmentShader(Effect.MapTexture, name + ".frag");
        effect.configChanged.connect(this.readConfig.bind(this));
        effects.windowAdded.connect(this.added.bind(this));
        effects.windowClosed.connect(this.closed.bind(this));
        this.readConfig();
    }

    readConfig() {
        this.effect = String(effect.readConfig("Effect", "glitch")).trim().toLowerCase();
        this.speed = Math.max(0.1, Number(effect.readConfig("Speed", 1.0)) || 1.0);
        this.durationIn = Number(effect.readConfig("DurationIn", 0)) || 0;
        this.durationOut = Number(effect.readConfig("DurationOut", 0)) || 0;
        const intensity = effect.readConfig("Intensity", 1.0);
        for (const name of SHADERS) uniform(this.shader[name], "uIntensity", intensity);
        uniform(this.shader.glitch, "uBands", Math.max(2, effect.readConfig("Bands", 14)));
    }

    duration(opening) {
        const fixed = opening ? this.durationIn : this.durationOut;
        if (fixed > 0) return animationTime(fixed);
        const base = DURATIONS[this.effect] || DURATIONS.glitch;
        return animationTime(Math.round(base[opening ? 0 : 1] / this.speed));
    }

    // Claudio is a Ghostty layer-shell surface. To KWin it is a "normal" window; it stands out by having no decoration,
    // being on all desktops and not showing up in the task switcher (normal Ghostty windows are decorated).
    static isClaudio(w) {
        return w && String(w.windowClass).indexOf("ghostty") !== -1 && !w.hasDecoration && w.skipSwitcher && w.onAllDesktops
            && !w.popupWindow && !w.tooltip;
    }

    clear(w) {
        for (const a of ["animIn", "animOut"]) {
            if (w[a]) { cancel(w[a]); delete w[a]; }
        }
    }

    animate(w, opening) {
        const duration = this.duration(opening);
        if (this.effect === "slide") {
            // from/to the right edge of the screen (where the sidebar is docked)
            const outside = { value1: effects.virtualScreenGeometry.x + effects.virtualScreenGeometry.width - w.x, value2: 0 };
            const inside = { value1: 0, value2: 0 };
            return animate({
                window: w, duration: duration,
                curve: opening ? QEasingCurve.OutCubic : QEasingCurve.InCubic,
                type: Effect.Translation,
                from: opening ? outside : inside, to: opening ? inside : outside
            });
        }
        const shader = this.shader[this.effect];
        if (shader !== undefined) {
            uniform(shader, "uForOpening", opening ? 1.0 : 0.0);
            uniform(shader, "uSeed", Math.random());
            // opacity leaves the content alone (the shader ignores it) but drives the blur behind the window (KWin's blur or
            // Better Blur DX): the frosted background arrives together with the content instead of being there from frame one
            return animate({
                window: w, duration: duration, curve: QEasingCurve.Linear,
                animations: [
                    { type: Effect.ShaderUniform, fragmentShader: shader, uniform: "uProgress", from: 0.0, to: 1.0 },
                    { type: Effect.Opacity, from: opening ? 0.0 : 1.0, to: opening ? 1.0 : 0.0,
                      curve: opening ? QEasingCurve.InQuad : QEasingCurve.OutQuad }
                ]
            });
        }
        return null;   // none
    }

    added(w) {
        if (!ClaudioReveal.isClaudio(w) || !w.visible || effects.hasActiveFullScreenEffect) return;
        this.clear(w);
        effect.grab(w, Effect.WindowAddedGrabRole, true);
        w.setData(Effect.WindowForceBlurRole, true);
        w.animIn = this.animate(w, true);
    }

    closed(w) {
        if (!ClaudioReveal.isClaudio(w) || !w.visible || effects.hasActiveFullScreenEffect) return;
        this.clear(w);
        effect.grab(w, Effect.WindowClosedGrabRole, true);
        w.setData(Effect.WindowForceBlurRole, true);
        w.animOut = this.animate(w, false);
    }
}

new ClaudioReveal();
