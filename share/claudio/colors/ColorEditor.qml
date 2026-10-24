// Claudio's colour editor (started by claudio-colors): pick one of the built-in themes or make your own, with a live
// preview drawn by the same shader as the real glow. Every change is written straight to colors.conf, which the glow
// (KWin script claudio-glow) and the tray icon pick up by themselves.
// Arguments after "--": colors.conf to edit, default colors.conf, themes.json, and how to show the first one. File access goes through XMLHttpRequest
// (claudio-colors sets QML_XHR_ALLOW_FILE_READ/WRITE).
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: win
    title: "Claudio colours"
    width: 640
    height: 720
    minimumWidth: 560
    minimumHeight: 640
    visible: true
    color: bg

    // its own dark look, in tune with Claudio, whatever the desktop colour scheme
    readonly property color bg: "#12151c"
    readonly property color card: "#1b1f28"
    readonly property color fg: "#e6e8ee"
    readonly property color accent: glow.color1 || "#2fb4ff"
    palette.window: bg
    palette.windowText: fg
    palette.text: fg
    palette.buttonText: fg
    palette.button: "#252a35"
    palette.base: "#1b1f28"
    palette.mid: "#3a4150"
    palette.highlight: accent
    palette.highlightedText: "#0b0e14"

    readonly property var args: {
        const a = Qt.application.arguments;
        const i = a.indexOf("--");
        return i < 0 ? [] : a.slice(i + 1);
    }
    readonly property string confPath: args[0] || ""
    readonly property var keys: ["color1", "color2", "color3", "color4", "highlight"]
    readonly property string confHeader: "; Claudio's colours: the animated glow around the sidebar (KWin script claudio-glow), the tray icon while Claude is\n"
        + "; working (claudio-tray) and the active tab. Pick a theme or make your own with the colour editor (claudio-colors, also in\n"
        + "; the tray menu → Glow → Customise colours…). Changes show up by themselves within a few seconds.\n"
        + "; [glow] holds the colours in use; [custom] keeps your own theme while a built-in one is selected.\n"

    property var themes: ({})
    property var themeIds: []
    property string theme: "custom"
    property var glow: ({})
    property var custom: ({})

    // ---- files ----
    function readFile(path) {
        const x = new XMLHttpRequest();
        x.open("GET", "file://" + path, false);
        try { x.send(); } catch (e) { return ""; }
        return x.responseText || "";
    }
    // writes are asynchronous (a synchronous PUT to a file:// URL writes nothing): one at a time, always the latest text
    property string pendingText: ""
    property bool writing: false
    property bool quitWhenSaved: false
    function writeConf(text) {
        pendingText = text;
        if (!writing) flush();
    }
    function flush() {
        const text = pendingText;
        pendingText = "";
        writing = true;
        const x = new XMLHttpRequest();
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            writing = false;
            if (pendingText !== "") flush();
            else if (quitWhenSaved) Qt.quit();
        };
        x.open("PUT", "file://" + confPath);
        x.send(text);
    }
    function close_() {
        if (writing || pendingText !== "") quitWhenSaved = true;
        else Qt.quit();
    }
    function parseIni(text) {
        const out = {};
        let sec = "";
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line === "" || line[0] === ";" || line[0] === "#") continue;
            if (line[0] === "[") { sec = line.slice(1, line.indexOf("]")).trim(); out[sec] = out[sec] || {}; continue; }
            const eq = line.indexOf("=");
            if (eq > 0 && sec) out[sec][line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
        }
        return out;
    }
    function pick(obj) {
        const o = {};
        for (const k of keys) o[k] = (obj && obj[k]) ? String(obj[k]) : "";
        return o;
    }
    function themeColors(t) {
        const o = {};
        const c = t.colors || [];
        for (let i = 0; i < 4; i++) o[keys[i]] = c[i] || "";
        o.highlight = t.highlight || "";
        return o;
    }
    function same(a, b) { return keys.every(k => (a[k] || "").toLowerCase() === (b[k] || "").toLowerCase()); }

    function load() {
        try { themes = JSON.parse(readFile(args[2] || "")); } catch (e) { themes = {}; }
        themeIds = Object.keys(themes).concat(["custom"]);
        let ini = parseIni(readFile(confPath));
        if (!ini.glow) ini = parseIni(readFile(args[1] || ""));
        glow = pick(ini.glow);
        custom = ini.custom ? pick(ini.custom) : pick(ini.glow);
        theme = (ini.glow && ini.glow.theme) ? ini.glow.theme.toLowerCase() : "";
        if (theme === "")   // colors.conf from before themes
            theme = Object.keys(themes).find(id => same(themeColors(themes[id]), glow)) || "custom";
    }
    function save() {
        let text = confHeader + "\n[glow]\n; aurora, nebula, ember or custom\ntheme=" + theme + "\n";
        for (const k of keys) text += k + "=" + (glow[k] || "") + "\n";
        text += "\n[custom]\n";
        for (const k of keys) text += k + "=" + (custom[k] || "") + "\n";
        writeConf(text);
        preview.replay();
    }

    function selectTheme(id) {
        if (id !== "custom" && !themes[id]) return;
        theme = id;
        glow = id === "custom" ? pick(custom) : themeColors(themes[id]);
        save();
    }
    // editing a colour starts from what is on screen and switches to the custom theme
    function setCustom(key, value) {
        const c = theme === "custom" ? pick(custom) : pick(glow);
        c[key] = value;
        if (key === "color3" && value === "") c.color4 = "";   // colour 4 only counts after colour 3
        custom = c;
        theme = "custom";
        glow = pick(c);
        save();
    }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function hex(c) { return "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join(""); }
    function colorsOf(o) { return keys.slice(0, 4).map(k => o[k]).filter(c => c); }

    Component.onCompleted: load()
    onClosing: close => { if (writing || pendingText !== "") { close.accepted = false; close_(); } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        // ---- live preview: a mock Claudio with the real glow shader around it ----
        Rectangle {
            id: preview
            Layout.fillWidth: true
            Layout.preferredHeight: 230
            radius: 5 * 2
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#151a24" }
                GradientStop { position: 1; color: "#0b0e14" }
            }
            readonly property int margin: 26
            readonly property int r: 16
            readonly property real sx: width * 0.46
            property real trace: 1
            function replay() { traceAnim.restart(); }
            NumberAnimation { id: traceAnim; target: preview; property: "trace"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutSine }

            ShaderEffect {
                anchors.fill: parent
                property real time: 0
                property size area: Qt.size(width, height)
                property vector4d box: Qt.vector4d(preview.sx, preview.margin, width - preview.sx + preview.r * 2, height - 2 * preview.margin)
                property real radius: preview.r
                property color color1: win.glow.color1 || "#2fb4ff"
                property color color2: win.glow.color2 || "#ff8a2b"
                property color color3: win.glow.color3 || "#000000"
                property color color4: win.glow.color4 || "#000000"
                property real numColors: Math.max(2, win.colorsOf(win.glow).length)
                property color highlight: win.glow.highlight || "transparent"
                property vector4d hole: Qt.vector4d(0, 0, 0, 0)
                property real trace: preview.trace
                fragmentShader: Qt.resolvedUrl("../../kwin/scripts/claudio-glow/contents/ui/glow.frag.qsb")
                NumberAnimation on time { from: 0; to: 3600; duration: 3600 * 1000; loops: Animation.Infinite }
            }
            // the sidebar: rounded on the left, flush with the right edge
            Rectangle {
                x: preview.sx
                y: preview.margin
                width: preview.width - preview.sx + preview.r
                height: preview.height - 2 * preview.margin
                radius: preview.r
                color: "#d91c1f27"
                Column {
                    x: 16; y: 16
                    spacing: 7
                    Repeater {
                        model: ["> why is my wifi so slow?", "", "Checking NetworkManager…", "● Power saving is on for wlan0.",
                                "  Turning it off fixes the drops.", "", "> ok, do it"]
                        Text {
                            text: modelData
                            font.family: "monospace"
                            font.pixelSize: 11
                            color: modelData.startsWith(">") ? "#e8e8e8" : modelData.startsWith("●") ? "#9fd3ff" : "#a8adb7"
                        }
                    }
                }
            }
        }

        Label { text: "Theme"; font.pixelSize: 16; font.bold: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: win.themeIds
                delegate: AbstractButton {
                    id: card
                    required property string modelData
                    readonly property var colors: win.colorsOf(modelData === "custom" ? win.custom : win.themeColors(win.themes[modelData]))
                    readonly property bool selected: win.theme === modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1        // equal widths, whatever the label
                    Layout.preferredHeight: 86
                    hoverEnabled: true
                    onClicked: win.selectTheme(modelData)
                    readonly property string name: modelData === "custom" ? "Custom" : win.themes[modelData].name
                    Accessible.name: name
                    background: Rectangle {
                        radius: 5 * 2
                        color: card.hovered ? win.alpha(win.accent, 0.12) : win.card
                        border.width: card.selected ? 2 : 1
                        border.color: card.selected ? win.accent : win.alpha(win.fg, 0.15)
                    }
                    contentItem: ColumnLayout {
                        spacing: 5
                        Canvas {
                            id: swatch
                            Layout.fillWidth: true
                            Layout.margins: 5
                            Layout.preferredHeight: 34
                            onWidthChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const cs = card.colors.length ? card.colors : ["#555555"];
                                const g = ctx.createLinearGradient(0, 0, width, 0);
                                for (let i = 0; i < cs.length; i++)
                                    g.addColorStop(cs.length === 1 ? 0 : i / (cs.length - 1), cs[i]);
                                ctx.fillStyle = g;
                                ctx.beginPath();
                                ctx.roundedRect(0, 0, width, height, height / 2, height / 2);
                                ctx.fill();
                            }
                            Connections { target: card; function onColorsChanged() { swatch.requestPaint(); } }
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: (card.selected ? "● " : "") + card.name
                            font.bold: card.selected
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#2a2f3a" }

        Label { text: "Your theme"; font.pixelSize: 16; font.bold: true }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Changing a colour switches to your custom theme, starting from the colours on screen. "
                + "The glow cycles through 2 to 4 colours; the highlight is a brighter sweep that goes round once per cycle."
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: [
                    { key: "color1", label: "Colour 1", optional: false, fallback: "#2fb4ff" },
                    { key: "color2", label: "Colour 2", optional: false, fallback: "#ff8a2b" },
                    { key: "color3", label: "Colour 3", optional: true, fallback: "#e1306c" },
                    { key: "color4", label: "Colour 4", optional: true, fallback: "#fd1d1d" },
                    { key: "highlight", label: "Highlight", optional: true, fallback: "#ffffff" }
                ]
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property string value: win.glow[modelData.key] || ""
                    readonly property bool usable: modelData.key !== "color4" || (win.glow.color3 || "") !== ""
                    Layout.fillWidth: true
                    implicitHeight: rowLayout.implicitHeight
                    RowLayout {
                        id: rowLayout
                        anchors.fill: parent
                        spacing: 10
                        CheckBox {
                            opacity: row.modelData.optional ? 1 : 0   // still takes its space, so the rows line up
                            enabled: row.modelData.optional && row.usable
                            checked: row.value !== ""
                            onToggled: win.setCustom(row.modelData.key, checked ? row.modelData.fallback : "")
                        }
                        Label { text: row.modelData.label; Layout.preferredWidth: 18 * 6; opacity: row.usable ? 1 : 0.5 }
                        Button {
                            enabled: row.value !== ""
                            implicitWidth: 18 * 7
                            onClicked: { picker.key = row.modelData.key; picker.selectedColor = row.value; picker.open(); }
                            contentItem: RowLayout {
                                Rectangle {
                                    implicitWidth: 22; implicitHeight: 22; radius: 11
                                    color: row.value || "transparent"
                                    border.color: win.alpha(win.fg, 0.3)
                                }
                                Label { text: row.value || "none"; font.family: "monospace" }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                opacity: 0.6
                font.pixelSize: 11
                text: "Saved automatically to " + (win.args[3] || win.confPath)
            }
            Button { text: "Close"; icon.name: "dialog-close"; onClicked: win.close_() }
        }
    }

    ColorDialog {
        id: picker
        property string key
        title: "Choose a colour"
        onAccepted: win.setCustom(key, win.hex(selectedColor))
    }
}
