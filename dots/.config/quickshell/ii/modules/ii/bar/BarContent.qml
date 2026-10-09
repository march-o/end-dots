import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0

    property alias clockIsland: barLeftSideMouseArea
    property alias systemIsland: leftCenterGroup
    property alias mediaIsland: mediaCenterGroup.glassFrame
    readonly property real mediaSurfaceHeight: root.useShortenedForm < 2 ? 438 + Appearance.sizes.baseBarHeight : 0
    property alias workspaceIsland: middleCenterGroup
    property alias statusIsland: barRightSideMouseArea

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Appearance.sizes.hyprlandGapsOut
        }
        implicitWidth: leftSectionClock.implicitWidth + 16
        height: Appearance.sizes.baseBarHeight
        width: implicitWidth

        BarGlassIsland { anchors.fill: parent }

        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        // Visual content
        ScrollHint {
            reveal: barLeftSideMouseArea.hovered
            color: leftSectionClock.textColor
            icon: Hyprsunset.gamma === 100 ? "light_mode" : "wb_twilight"
            tooltipText: Translation.tr("Scroll to change brightness")
            side: "left"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        LeftTimeWidget {
            id: leftSectionClock
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
        }
    }

        BarGroup {
            id: leftCenterGroup
            glass: true
            anchors.verticalCenter: parent.verticalCenter
            x: (barLeftSideMouseArea.x + barLeftSideMouseArea.width + middleCenterGroup.x - width) / 2

            Resources {
                alwaysShowAllResources: root.useShortenedForm === 2
            }
        }

        BarGroup {
            id: middleCenterGroup
            glass: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter

            Workspaces {
                id: workspacesWidget
                Layout.fillHeight: true
                MouseArea {
                    // Right-click to toggle overview
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton

                    onPressed: event => {
                        if (event.button === Qt.RightButton) {
                            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                        }
                    }
                }
            }
        }

        BarGroup {
            id: mediaCenterGroup
            glass: true
            glassWidth: width
            glassHeight: height + mediaWidget.expansionProgress * (438 - height)
            glassFrame.colorTarget: mediaWidget
            glassFrame.color: Config.options.bar.showBackground ? Qt.rgba(
                1 + (mediaWidget.glassTint.r - 1) * mediaWidget.expansionProgress,
                1 + (mediaWidget.glassTint.g - 1) * mediaWidget.expansionProgress,
                1 + (mediaWidget.glassTint.b - 1) * mediaWidget.expansionProgress,
                0.035 + (mediaWidget.glassTintOpacity - 0.035) * mediaWidget.expansionProgress) : "transparent"
            visible: root.useShortenedForm < 2
            anchors.verticalCenter: parent.verticalCenter
            x: (middleCenterGroup.x + middleCenterGroup.width + barRightSideMouseArea.x - width) / 2
            implicitWidth: (root.useShortenedForm === 0 ? 240 : 115) * (1 - mediaWidget.expansionProgress) + 320 * mediaWidget.expansionProgress

            Media {
                id: mediaWidget
                glassFrame: mediaCenterGroup.glassFrame
                Layout.fillWidth: true
            }
        }

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Appearance.sizes.hyprlandGapsOut
        }
        implicitWidth: rightSectionRowLayout.implicitWidth + 10
        width: implicitWidth
        height: Appearance.sizes.baseBarHeight

        BarGlassIsland { anchors.fill: parent }

        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        // Visual content
        ScrollHint {
            reveal: barRightSideMouseArea.hovered
            color: rightSidebarButton.colText
            icon: "volume_up"
            tooltipText: Translation.tr("Scroll to change volume")
            side: "right"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            id: rightSectionRowLayout
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 5
            layoutDirection: Qt.RightToLeft

            RippleButton { // Right sidebar button
                id: rightSidebarButton

                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.rightMargin: 0
                Layout.fillWidth: false

                implicitWidth: indicatorsRowLayout.implicitWidth + 10 * 2
                implicitHeight: indicatorsRowLayout.implicitHeight + 5 * 2

                WallpaperIconColor { id: statusPalette; target: rightSidebarButton }
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: "transparent"
                colBackgroundToggled: "transparent"
                colBackgroundToggledHover: "transparent"
                rippleEnabled: false
                toggled: GlobalStates.sidebarRightOpen
                property color colText: toggled
                    ? (hovered ? statusPalette.statePalette.onHover : statusPalette.statePalette.on)
                    : (hovered ? statusPalette.statePalette.offHover : statusPalette.statePalette.off)

                Behavior on colText {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                onPressed: {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                }

                RowLayout {
                    id: indicatorsRowLayout
                    anchors.centerIn: parent
                    property real realSpacing: 15
                    spacing: 0

                    Revealer {
                        reveal: Audio.sink?.audio?.muted ?? false
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: "volume_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        reveal: Audio.source?.audio?.muted ?? false
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: "mic_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    HyprlandXkbIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                        color: rightSidebarButton.toggled
                            ? (rightSidebarButton.hovered ? statusPalette.textStatePalette.onHover : statusPalette.textStatePalette.on)
                            : (rightSidebarButton.hovered ? statusPalette.textStatePalette.offHover : statusPalette.textStatePalette.off)
                    }
                    Revealer {
                        reveal: Notifications.silent || Notifications.unread > 0
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        NotificationUnreadCount {
                            id: notificationUnreadCount
                            color: rightSidebarButton.colText
                            indicatorColor: statusPalette.statePalette.on
                        }
                    }
                    MaterialSymbol {
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: Network.ethernet || Network.wifi
                            ? (rightSidebarButton.hovered ? statusPalette.statePalette.onHover : statusPalette.statePalette.on)
                            : rightSidebarButton.colText
                    }
                    MaterialSymbol {
                        Layout.leftMargin: indicatorsRowLayout.realSpacing
                        visible: BluetoothStatus.available
                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: Appearance.font.pixelSize.larger
                        color: BluetoothStatus.enabled
                            ? (rightSidebarButton.hovered ? statusPalette.statePalette.onHover : statusPalette.statePalette.on)
                            : rightSidebarButton.colText
                    }
                }
            }

            SysTray {
                visible: root.useShortenedForm === 0
                Layout.fillWidth: false
                Layout.fillHeight: true
                invertSide: Config?.options.bar.bottom
            }

            BatteryIndicator {
                visible: root.useShortenedForm < 2 && Battery.available
                Layout.alignment: Qt.AlignVCenter
            }
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Layout.alignment: Qt.AlignVCenter
                color: Qt.rgba(statusPalette.iconColor.r, statusPalette.iconColor.g, statusPalette.iconColor.b, 0.35)
            }
            UtilButtons {
                id: utilityButtons
                visible: Config.options.bar.verbose && root.useShortenedForm === 0
                Layout.alignment: Qt.AlignVCenter
            }
            GlassButton {
                statePalette: utilityButtons.statePalette
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.home)}/.local/bin/wallpaper-next`])
                GlassIcon {
                    text: "wallpaper_slideshow"
                    iconSize: Appearance.font.pixelSize.large * 1.25
                }
            }

            // Weather
            Loader {
                Layout.leftMargin: 4
                active: Config.options.bar.weather.enable

                sourceComponent: BarGroup {
                    WeatherBar {}
                }
            }
        }
    }
}
