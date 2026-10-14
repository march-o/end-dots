import qs.modules.ii.sidebarRight
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small
    
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: 12
        height: 2
        radius: 1
        visible: button.toggled
        color: GlassColors.states.on
    }

    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: button.toggled
            ? (button.hovered ? GlassColors.textStates.onHover : GlassColors.textStates.on)
            : (button.hovered ? GlassColors.textStates.offHover : GlassColors.textStates.off)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}

