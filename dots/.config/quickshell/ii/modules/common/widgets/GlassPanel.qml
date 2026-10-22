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
    property bool drawSurface: true
    property color surfaceTint: GlassColors.surface
    property color foregroundColor: GlassColors.foreground
    property alias radius: panelFrame.radius
    readonly property alias contentItem: panelContent
    readonly property var glassColors: GlassColors.colorsFor(surfaceTint, foregroundColor)
    readonly property var glassM3Colors: Object.assign({}, GlassColors.m3colors, {
        m3onBackground: foregroundColor, m3onSurface: foregroundColor,
        m3onSurfaceVariant: foregroundColor
    })
    readonly property var statePalette: BarGlassPalette.islandButtonColors(surfaceTint)
    readonly property var textStatePalette: BarGlassPalette.islandButtonColors(surfaceTint, 4.5)
    default property alias contentData: panelContent.data

    BarGlassIsland {
        id: panelFrame
        visible: root.drawSurface
        anchors { fill: parent; margins: root.frameInset }
        radius: BarGeometry.cornerRadius
        tintColor: root.surfaceTint
        wallpaperAmount: root.drawSurface ? root.wallpaperAmount : 0
        wallpaperNamespace: root.layerNamespace
    }

    Item {
        id: panelContent
        anchors { fill: parent; margins: root.frameInset + root.contentPadding }
    }
}
