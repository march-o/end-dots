import qs.modules.ii.sidebarRight
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

GroupButton {
    id: button
    readonly property var colorStates: GlassColors.states
    readonly property color foreground: toggled
        ? (hovered ? colorStates.onHover : colorStates.on)
        : (hovered ? colorStates.offHover : colorStates.off)
    property string buttonIcon
    baseWidth: 40
    baseHeight: 40
    clickedWidth: baseWidth + 20
    toggled: false
    buttonRadius: (altAction && toggled) ? Appearance?.rounding.normal : Math.min(baseHeight, baseWidth) / 2
    buttonRadiusPressed: Appearance?.rounding?.small

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 22
        fill: toggled ? 1 : 0
        color: button.foreground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: buttonIcon

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

}
