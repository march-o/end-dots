import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

Item {
    id: root
    implicitWidth: clockText.implicitWidth
    implicitHeight: 32

    StyledText {
        id: clockText
        anchors.centerIn: parent
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: DateTime.time + "  |  " + Qt.locale().toString(DateTime.clock.date, "ddd MMM d").toUpperCase()
        font.pixelSize: Appearance.font.pixelSize.normal
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
