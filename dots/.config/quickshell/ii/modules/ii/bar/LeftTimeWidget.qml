import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

Item {
    id: root
    implicitWidth: clockText.implicitWidth + 12
    implicitHeight: Appearance.sizes.baseBarHeight

    StyledText {
        id: clockText
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: DateTime.time + "  |  " + Qt.locale().toString(DateTime.clock.date, "MMM d").toUpperCase()
        font.pixelSize: Appearance.font.pixelSize.huge
        font.weight: Font.Medium
        color: Appearance.colors.colOnLayer0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        ClockWidgetPopup { hoverTarget: mouseArea }
    }
}
