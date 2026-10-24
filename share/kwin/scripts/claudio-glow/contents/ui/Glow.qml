// Glow window (loaded by Logic.qml through a Loader, like KWin's own system scripts do): transparent to clicks,
// never focused; the shader only draws the outer edge fading out around the sidebar.
import QtCore
import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore

PlasmaCore.Dialog {
    id: glow
    property int margin: 28
    property int radius: 16
    // colours shared by all of Claudio (the tray icon too): ~/.config/claudio/colors.conf
    property color color1: "#2fb4ff"
    property color color2: "#ff8a2b"
    property color color3: "#e1306c"
    property color color4: "#fd1d1d"
    property int numColors: 4
    property color highlight: "transparent"

    // read only (no property declared in Settings, so the file is never written)
    property Settings conf: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/claudio/colors.conf"
    }
    function readColors() {
        conf.sync();   // re-reads the file if it changed
        if (String(conf.value("glow/color1", "")).trim() === "")
            return;    // no colors.conf yet: keep the defaults above
        color1 = conf.value("glow/color1", "#2fb4ff");
        color2 = conf.value("glow/color2", "#ff8a2b");
        // color3 and color4 are optional
        const c3 = String(conf.value("glow/color3", "")).trim();
        const c4 = String(conf.value("glow/color4", "")).trim();
        numColors = c3 === "" ? 2 : (c4 === "" ? 3 : 4);
        if (c3 !== "") color3 = c3;
        if (c4 !== "") color4 = c4;
        // empty highlight = none (transparent colour: the shader uses its alpha as the intensity)
        const h = String(conf.value("glow/highlight", "")).trim();
        highlight = h === "" ? "transparent" : h;
    }
    Component.onCompleted: readColors()
    property Timer reload: Timer {
        interval: 3000; repeat: true
        running: glow.visible
        onTriggered: glow.readColors()
    }

    // The glow traces itself along the edge while Claudio appears, in the same time as the reveal effect
    // (claudio_reveal): the duration is read from kwinrc the way main.js computes it (DURATIONS / Speed, or DurationIn).
    property real trace: 1
    property Settings kwin: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kwinrc"
        category: "Effect-claudio_reveal"
    }
    property Settings kdeglobals: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kdeglobals"
        category: "KDE"
    }
    function revealDuration() {
        kwin.sync();
        kdeglobals.sync();
        let ms = Number(kwin.value("DurationIn", 0)) || 0;
        if (ms <= 0) {
            const base = { glitch: 300, decrypt: 650, scan: 520, slide: 220, none: 0 };
            const e = String(kwin.value("Effect", "glitch")).trim().toLowerCase();
            const speed = Math.max(0.1, Number(kwin.value("Speed", 1.0)) || 1.0);
            ms = (e in base ? base[e] : 300) / speed;
        }
        const factor = Number(kdeglobals.value("AnimationDurationFactor", 1));
        return Math.max(150, ms * (isNaN(factor) ? 1 : factor));
    }
    property NumberAnimation traceAnimation: NumberAnimation {
        target: glow; property: "trace"; from: 0; to: 1
        easing.type: Easing.InOutSine
    }

    function showAround(g) {
        if (!visible || content.opacity === 0) {
            traceAnimation.duration = revealDuration();
            trace = 0;
            traceAnimation.restart();
        }
        // on the right the sidebar touches the edge of the screen: no margin there
        x = g.x - margin;
        y = g.y - margin;
        content.width = g.width + margin;      // the Dialog takes its size from its mainItem
        content.height = g.height + 2 * margin;
        visible = true;
        content.opacity = 1;
    }

    // KRunner (rectangle in screen coordinates, or null): the glow does not draw over it
    property rect screenHole: Qt.rect(0, 0, 0, 0)
    function hole(g) {
        screenHole = g ? Qt.rect(g.x, g.y, g.width, g.height) : Qt.rect(0, 0, 0, 0);
    }

    function fadeOut() {
        content.opacity = 0;
    }

    visible: false
    backgroundHints: PlasmaCore.Dialog.NoBackground
    type: PlasmaCore.Dialog.OnScreenDisplay
    location: PlasmaCore.Types.Floating
    outputOnly: true          // transparent to clicks
    hideOnWindowDeactivate: false
    flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
           | Qt.WindowDoesNotAcceptFocus

    mainItem: Item {
        id: content
        opacity: 0
        Behavior on opacity {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
                onRunningChanged: if (!running && content.opacity === 0) glow.visible = false
            }
        }
        ShaderEffect {
            anchors.fill: parent
            property real time: 0
            property size area: Qt.size(width, height)
            property vector4d box: Qt.vector4d(glow.margin, glow.margin,
                                                content.width - glow.margin + glow.radius * 2,
                                                content.height - 2 * glow.margin)
            property real radius: glow.radius
            property color color1: glow.color1
            property color color2: glow.color2
            property color color3: glow.color3
            property color color4: glow.color4
            property real numColors: glow.numColors
            property vector4d hole: Qt.vector4d(glow.screenHole.x - glow.x, glow.screenHole.y - glow.y,
                                                glow.screenHole.width, glow.screenHole.height)
            property color highlight: glow.highlight
            property real trace: glow.trace
            fragmentShader: Qt.resolvedUrl("glow.frag.qsb?v=" + Date.now())
            NumberAnimation on time {
                from: 0; to: 3600; duration: 3600 * 1000
                loops: Animation.Infinite
                running: glow.visible
            }
        }
    }
}
