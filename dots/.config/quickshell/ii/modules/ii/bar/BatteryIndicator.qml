import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    WallpaperIconColor { id: localColors; target: root }
    property color iconColor: isLow && !isCharging ? localColors.warningColor
        : isCharging ? (containsMouse ? localColors.statePalette.onHover : localColors.statePalette.on)
        : (containsMouse ? localColors.statePalette.offHover : localColors.statePalette.off)
    property color textColor: isLow && !isCharging ? localColors.warningColor
        : isCharging ? (containsMouse ? localColors.textStatePalette.onHover : localColors.textStatePalette.on)
        : (containsMouse ? localColors.textStatePalette.offHover : localColors.textStatePalette.off)
    implicitWidth: row.implicitWidth
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 3
        MaterialSymbol {
            text: root.isCharging ? "battery_charging_full" : "battery_full"
            iconSize: Appearance.font.pixelSize.large * 1.25
            color: root.iconColor
            fill: 0
        }
        StyledText {
            text: Math.round(root.percentage * 100) + "%"
            color: root.textColor
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }
    }
    BatteryPopup { id: batteryPopup; hoverTarget: root }
}
