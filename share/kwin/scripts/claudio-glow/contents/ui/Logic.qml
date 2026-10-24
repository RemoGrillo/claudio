// Animated glow around Claudio (Ghostty quick terminal, instance io.github.remogrillo.claudio).
// The glow window (Glow.qml, a PlasmaCore.Dialog with no background, transparent to clicks) is a bit bigger than the
// sidebar: it sits on top of it, but its middle is empty and lets clicks through. Visible only while Claudio is open.
import QtQuick
import org.kde.kwin

Loader {
    id: root
    property var sidebar: null
    property var krunner: null
    source: "Glow.qml?v=" + Date.now()

    function isClaudio(w) {
        return w && w.resourceClass === "ghostty" && w.layer === 3 && !w.dock;
    }

    function attach(w) {
        root.sidebar = w;
        if (root.item)
            root.item.showAround(w.frameGeometry);
    }

    // KRunner sits above the sidebar but below the glow (which is at OSD level): the glow leaves a hole for it
    function isKrunner(w) {
        return w && w.resourceClass === "krunner";
    }

    function updateHole() {
        if (root.item)
            root.item.hole(root.krunner ? root.krunner.frameGeometry : null);
    }

    onLoaded: {
        const windows = Workspace.stackingOrder;
        for (let i = 0; i < windows.length; i++) {
            if (isClaudio(windows[i]))
                attach(windows[i]);
            else if (isKrunner(windows[i]))
                root.krunner = windows[i];
        }
        updateHole();
    }

    Connections {
        target: Workspace
        function onWindowAdded(w) {
            if (root.isClaudio(w))
                root.attach(w);
            else if (root.isKrunner(w)) {
                root.krunner = w;
                root.updateHole();
            }
        }
        function onWindowRemoved(w) {
            if (w === root.sidebar) {
                root.sidebar = null;
                root.item.fadeOut();
            } else if (w === root.krunner) {
                root.krunner = null;
                root.updateHole();
            }
        }
    }

    Connections {
        target: root.krunner
        ignoreUnknownSignals: true
        function onFrameGeometryChanged() { root.updateHole(); }
        function onHiddenChanged() { root.updateHole(); }
    }

    Connections {
        target: root.sidebar
        ignoreUnknownSignals: true
        function onFrameGeometryChanged() { root.item.showAround(root.sidebar.frameGeometry); }
    }
}
