import QtQuick
import qs.modules.common

Rectangle {
    id: root
    property Item colorTarget: root
    WallpaperIconColor { id: frameColors; target: root.colorTarget }
    readonly property color outlineColor: BarGlassPalette.readableColor(
        [Appearance.m3colors.m3primary, Appearance.m3colors.m3primaryContainer,
         Appearance.m3colors.m3onPrimaryFixedVariant, Appearance.m3colors.m3secondary],
        frameColors.sampledBackground, 2)
    color: Config.options.bar.showBackground ? Qt.rgba(1, 1, 1, 0.035) : "transparent"
    radius: Math.min(height / 2, Appearance.rounding.windowRounding)
    border.width: Config.options.bar.showBackground ? 2 : 0
    border.color: Qt.rgba(outlineColor.r, outlineColor.g, outlineColor.b, 0.40)

    // Reflections follow each island, rather than the full layer surface.
    readonly property color reflectionColor: Qt.rgba(
        0.65 + outlineColor.r * 0.35,
        0.65 + outlineColor.g * 0.35,
        0.65 + outlineColor.b * 0.35, 1)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.max(0, root.radius - 2)
        visible: root.border.width > 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, 0.34) }
            GradientStop { position: 0.38; color: Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, 0.035) }
            GradientStop { position: 0.68; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, 0.14) }
        }
    }
    Rectangle {
        x: root.radius + 2
        y: 2
        width: Math.max(0, root.width - 2 * x)
        height: 1
        visible: root.border.width > 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.25; color: Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, 0.65) }
            GradientStop { position: 0.70; color: Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, 0.15) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        x: root.radius + 2
        y: root.height - 3
        width: Math.max(0, root.width - 2 * x)
        height: 1
        visible: root.border.width > 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.35; color: Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, 0.32) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
