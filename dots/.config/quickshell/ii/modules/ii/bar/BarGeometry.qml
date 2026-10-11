pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    // Insets belong to the island, never to both the island and its content.
    readonly property real cornerRadius: 20
    readonly property real minimumTintOpacity: 0.32
    readonly property real maximumTintOpacity: 0.86
    readonly property real textLift: 0.72
    readonly property real seamOpacity: 0.84
    readonly property real seamHighlightOpacity: 0.46
    readonly property real groupPadding: 5
    readonly property real edgePadding: 10
    readonly property real spacing: 4
    readonly property real iconSize: Math.round(Appearance.font.pixelSize.large * 1.25)
    readonly property real buttonSize: Math.max(32, Math.ceil(iconSize * 1.2))
}
