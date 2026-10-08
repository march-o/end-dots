import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    WallpaperIconColor { id: iconColors; target: resourceCircProg }
    WallpaperIconColor { id: valueColors; target: percentageText }
    required property string iconName
    required property double percentage
    property int warningThreshold: 100
    property bool shown: true
    property bool groupHovered: false
    property var statePalette: iconColors.statePalette
    property var textStatePalette: valueColors.textStatePalette
    property color warningColor: valueColors.warningColor
    property color iconColor: warning ? iconColors.warningColor : groupHovered ? statePalette.offHover : statePalette.off
    property color textColor: warning ? warningColor : groupHovered ? textStatePalette.offHover : textStatePalette.off
    Behavior on iconColor { ColorAnimation { duration: 120 } }
    Behavior on textColor { ColorAnimation { duration: 120 } }
    clip: true
    visible: width > 0 && height > 0
    implicitWidth: resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight
    property bool warning: percentage * 100 >= warningThreshold

    RowLayout {
        id: resourceRowLayout
        spacing: 4
        x: shown ? 0 : -resourceRowLayout.width
        anchors {
            verticalCenter: parent.verticalCenter
        }

        CircularProgress {
            id: resourceCircProg
            Layout.alignment: Qt.AlignVCenter
            lineWidth: 1
            value: percentage
            implicitSize: 24
            colPrimary: root.iconColor
            colSecondary: "transparent"
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: resourceCircProg.implicitSize
                height: resourceCircProg.implicitSize
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.iconColor
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: fullPercentageTextMetrics.width
            implicitHeight: percentageText.implicitHeight

            TextMetrics {
                id: fullPercentageTextMetrics
                text: "100"
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                id: percentageText
                anchors.centerIn: parent
                color: root.textColor
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                text: `${Math.round(percentage * 100).toString()}`
            }
        }

        Behavior on x {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: resourceRowLayout.x >= 0 && root.width > 0 && root.visible
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }
}
