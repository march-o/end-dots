pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.ii.bar
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    WallpaperIconColor { id: localColors; target: root }
    property color iconColor: containsMouse ? localColors.statePalette.offHover : localColors.statePalette.off
    property color textColor: containsMouse ? localColors.textStatePalette.offHover : localColors.textStatePalette.off
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onPressed: {
        if (mouse.button === Qt.RightButton) {
            Weather.getData();
            Quickshell.execDetached(["notify-send", 
                Translation.tr("Weather"), 
                Translation.tr("Refreshing (manually triggered)")
                , "-a", "Shell"
            ])
            mouse.accepted = false
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        MaterialSymbol {
            fill: 0
            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
            iconSize: Appearance.font.pixelSize.large
            color: root.iconColor
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.textColor
            text: Weather.data?.temp ?? "--°"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
    }
}
