// Entry point: loads Logic.qml from an ever-changing URL, so KWin does not reuse a stale copy from its cache when the
// script is reloaded (otherwise changes would need a KWin restart).
import QtQuick

Loader {
    source: "Logic.qml?v=" + Date.now()
}
