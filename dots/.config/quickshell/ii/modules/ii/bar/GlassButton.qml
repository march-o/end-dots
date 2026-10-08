import QtQuick

CircleUtilButton {
    id: root
    property var statePalette: BarGlassPalette.buttonColors(BarGlassPalette.dominant)
    property color iconColor: toggled
        ? (hovered ? statePalette.onHover : statePalette.on)
        : (hovered ? statePalette.offHover : statePalette.off)
    property Binding iconColorBinding: Binding { target: root.content; property: "color"; value: root.iconColor }
    implicitHeight: Math.max(content.implicitHeight, 26 * 1.25)
    colBackground: "transparent"
    colBackgroundHover: "transparent"
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: "transparent"
    rippleEnabled: false
    Behavior on iconColor { ColorAnimation { duration: 120 } }
}
