import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.ii.bar

// Shared foundation for floating shell widgets. Child controls inherit the
// semantic palette through ScopedColors; the backdrop follows the desktop.
FocusScope {
    id: root
    property string layerNamespace: root.QsWindow.window?.layerNamespace ?? "quickshell:glass-panel"
    property real frameInset: 0
    property real contentPadding: 12
    property real wallpaperAmount: 1
    property alias radius: panelFrame.radius
    readonly property alias contentItem: panelContent
    readonly property var glassColors: GlassColors.colors
    readonly property var glassM3Colors: GlassColors.m3colors
    readonly property var statePalette: GlassColors.states
    readonly property var textStatePalette: GlassColors.textStates
    default property alias contentData: panelContent.data

    BarGlassIsland {
        id: panelFrame
        anchors { fill: parent; margins: root.frameInset }
        radius: BarGeometry.cornerRadius
        wallpaperAmount: root.wallpaperAmount
        wallpaperNamespace: root.layerNamespace
    }

    Item {
        id: panelContent
        anchors { fill: parent; margins: root.frameInset + root.contentPadding }
    }
}
