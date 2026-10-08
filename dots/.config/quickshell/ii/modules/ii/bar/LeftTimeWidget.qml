import qs.modules.common
import qs.modules.common.widgets
import qs
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: clockRow.implicitWidth + 20
    implicitHeight: Appearance.sizes.baseBarHeight

    WallpaperIconColor { id: timeColors; target: timeText }
    WallpaperIconColor { id: dateColors; target: dateText }
    property color textColor: GlobalStates.sidebarLeftOpen
        ? (mouseArea.containsMouse ? timeColors.textStatePalette.onHover : timeColors.textStatePalette.on)
        : (mouseArea.containsMouse ? timeColors.textStatePalette.offHover : timeColors.textStatePalette.off)
    property color dateColor: GlobalStates.sidebarLeftOpen
        ? (mouseArea.containsMouse ? dateColors.textStatePalette.onHover : dateColors.textStatePalette.on)
        : (mouseArea.containsMouse ? dateColors.textStatePalette.offHover : dateColors.textStatePalette.off)
    Behavior on textColor { ColorAnimation { duration: 120 } }
    Behavior on dateColor { ColorAnimation { duration: 120 } }

    RowLayout {
        id: clockRow
        anchors.centerIn: parent
        spacing: 0
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
            text: "  |  " + Qt.locale().toString(DateTime.clock.date, "MMM d").toUpperCase()
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: Font.Medium
            color: root.dateColor
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
