import qs.modules.common
import qs.modules.common.widgets
import qs
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: clockRow.implicitWidth
    implicitHeight: Appearance.sizes.baseBarHeight
    readonly property real seamX: timeText.width + clockRow.spacing / 2

    WallpaperIconColor { id: clockColors; target: root }
    property color textColor: GlobalStates.sidebarLeftOpen
        ? (mouseArea.containsMouse ? clockColors.textStatePalette.onHover : clockColors.textStatePalette.on)
        : (mouseArea.containsMouse ? clockColors.textStatePalette.offHover : clockColors.textStatePalette.off)
    Behavior on textColor { ColorAnimation { duration: 120 } }

    RowLayout {
        id: clockRow
        anchors.centerIn: parent
        spacing: 20
        StyledText {
            id: timeText
            Layout.alignment: Qt.AlignVCenter
            text: DateTime.time
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: Font.Medium
            color: root.textColor
        }
        StyledText {
            id: dateText
            Layout.alignment: Qt.AlignVCenter
            text: Qt.locale().toString(DateTime.clock.date, "MMM d").toUpperCase()
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: Font.Medium
            color: root.textColor
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        ClockWidgetPopup { hoverTarget: mouseArea }
    }
}
