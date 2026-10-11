import QtQuick

CircleUtilButton {
    id: root
    property var statePalette: BarGlassPalette.islandButtonColors(BarGlassPalette.glassTint)
    property color iconColor: toggled
        ? (hovered ? statePalette.onHover : statePalette.on)
        : (hovered ? statePalette.offHover : statePalette.off)
    property Binding iconColorBinding: Binding { target: root.content; property: "color"; value: root.iconColor }
    // Neutralize Qt Controls style padding/insets: the glyph owns a square cell.
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    leftInset: 0
    rightInset: 0
    topInset: 0
    bottomInset: 0
    implicitWidth: BarGeometry.buttonSize
    implicitHeight: BarGeometry.buttonSize
    colBackground: "transparent"
    colBackgroundHover: "transparent"
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: "transparent"
    rippleEnabled: false
    Behavior on iconColor { ColorAnimation { duration: 120 } }
}
