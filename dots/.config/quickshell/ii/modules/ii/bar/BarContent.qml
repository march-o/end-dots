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
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width)
                                    ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width)
                                      ? 1 : 0

    property alias clockIsland: barLeftSideMouseArea
    property alias systemIsland: leftCenterGroup.glassFrame
    readonly property bool statsPresented: statsWidget.presented
    readonly property bool statsKeyboardMode: statsWidget.keyboardMode && statsWidget.expanded
    readonly property real statsSurfaceHeight: statsWidget.maximumExpandedHeight + Appearance.sizes.barHeight
    property alias mediaIsland: mediaCenterGroup.glassFrame
    readonly property real mediaSurfaceHeight: root.useShortenedForm < 2 ? 438
                                                                           + Appearance.sizes.baseBarHeight :
                                                                           0
    property alias workspaceIsland: middleCenterGroup
    property alias statusIsland: barRightSideMouseArea

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Appearance.sizes.hyprlandGapsOut
        }
        implicitWidth: clockGroup.implicitWidth
        height: Appearance.sizes.baseBarHeight
        width: implicitWidth

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

        BarGroup {
            id: clockGroup
            anchors.fill: parent
            glass: true
            padding: BarGeometry.edgePadding
            glassFrame.seams: [leftSectionClock.seamX + BarGeometry.edgePadding]
            LeftTimeWidget {
                id: leftSectionClock
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    BarGroup {
        id: leftCenterGroup
        glass: true
        padding: 0
        z: statsWidget.presented ? 3 : 0
        glassHeight: height + statsWidget.expansionProgress * (statsWidget.expandedHeight - height)
        glassOffsetY: Config.options.bar.bottom ? height - glassHeight : 0
        glassTint: ColorUtils.mix(GlassColors.monitorSurface, BarGlassPalette.glassTint, statsWidget.expansionProgress)
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(8, Math.min(root.width - width - 8,
            (barLeftSideMouseArea.x + barLeftSideMouseArea.width + middleCenterGroup.x - width) / 2))

        Item {
            implicitWidth: statsWidget.compactWidth * (1 - statsWidget.expansionProgress)
                + statsWidget.expandedWidth * statsWidget.expansionProgress
            implicitHeight: Appearance.sizes.baseBarHeight
        }
        Resources {
            id: statsWidget
            parent: leftCenterGroup.glassFrame
            anchors.fill: parent
            morphEnabled: true
            alwaysShowAllResources: root.useShortenedForm === 2
            onExpandedChanged: if (expanded) mediaWidget.closeCard()
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
        visible: root.useShortenedForm < 2
        anchors.verticalCenter: parent.verticalCenter
        x: (middleCenterGroup.x + middleCenterGroup.width + barRightSideMouseArea.x - width) / 2
        implicitWidth: (root.useShortenedForm === 0 ? 240 : 115) * (1 - mediaWidget.expansionProgress) + 320
                       * mediaWidget.expansionProgress

        Media {
            id: mediaWidget
            onExpandedChanged: if (expanded) statsWidget.dismiss()
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
        implicitWidth: statusGroup.implicitWidth
        width: implicitWidth
        height: Appearance.sizes.baseBarHeight

        onScrollDown: Audio.decrementVolume()
        onScrollUp: Audio.incrementVolume()
        onMovedAway: GlobalStates.osdVolumeOpen = false
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

        BarGroup {
            id: statusGroup
            anchors.fill: parent
            glass: true
            padding: BarGeometry.edgePadding
            glassFrame.seams: [BarGeometry.edgePadding + utilitySection.x + utilitySection.width + rightSectionRowLayout.spacing / 2]

            RowLayout {
                id: rightSectionRowLayout
                Layout.alignment: Qt.AlignVCenter
                spacing: 20
                layoutDirection: Qt.RightToLeft

                BarGroup {
                    glass: false
                    padding: 0
                    Layout.alignment: Qt.AlignVCenter
                    RippleButton { // Right sidebar button
                        id: rightSidebarButton

                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.rightMargin: 0
                        Layout.fillWidth: false

                        implicitWidth: indicatorsRowLayout.implicitWidth
                        implicitHeight: BarGeometry.buttonSize
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        leftInset: 0
                        rightInset: 0
                        topInset: 0
                        bottomInset: 0

                        WallpaperIconColor {
                            id: statusPalette
                            target: rightSidebarButton
                        }
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: "transparent"
                        colBackgroundToggled: "transparent"
                        colBackgroundToggledHover: "transparent"
                        rippleEnabled: false
                        toggled: GlobalStates.sidebarRightOpen
                        property color colText: toggled ? (hovered ? statusPalette.statePalette.onHover :
                                                                     statusPalette.statePalette.on) : (hovered
                                                                                                       ? statusPalette.statePalette.offHover :
                                                                                                         statusPalette.statePalette.off)

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
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(
                                                   this)
                                }
                                MaterialSymbol {
                                    text: "volume_off"
                                    iconSize: BarGeometry.iconSize
                                    color: rightSidebarButton.colText
                                }
                            }
                            Revealer {
                                reveal: Audio.source?.audio?.muted ?? false
                                Layout.fillHeight: true
                                Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                                Behavior on Layout.rightMargin {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(
                                                   this)
                                }
                                MaterialSymbol {
                                    text: "mic_off"
                                    iconSize: BarGeometry.iconSize
                                    color: rightSidebarButton.colText
                                }
                            }
                            HyprlandXkbIndicator {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.rightMargin: indicatorsRowLayout.realSpacing
                                color: rightSidebarButton.toggled ? (rightSidebarButton.hovered
                                                                     ? statusPalette.textStatePalette.onHover :
                                                                       statusPalette.textStatePalette.on) : (
                                                                        rightSidebarButton.hovered
                                                                        ? statusPalette.textStatePalette.offHover :
                                                                          statusPalette.textStatePalette.off)
                            }
                            Revealer {
                                reveal: Notifications.silent || Notifications.unread > 0
                                Layout.fillHeight: true
                                Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                                implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                                implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                                Behavior on Layout.rightMargin {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(
                                                   this)
                                }
                                NotificationUnreadCount {
                                    id: notificationUnreadCount
                                    color: rightSidebarButton.colText
                                    indicatorColor: statusPalette.statePalette.on
                                }
                            }
                            MaterialSymbol {
                                text: Network.materialSymbol
                                iconSize: BarGeometry.iconSize
                                color: Network.ethernet || Network.wifi ? (rightSidebarButton.hovered
                                                                           ? statusPalette.statePalette.onHover :
                                                                             statusPalette.statePalette.on) :
                                                                          rightSidebarButton.colText
                            }
                            MaterialSymbol {
                                Layout.leftMargin: indicatorsRowLayout.realSpacing
                                visible: BluetoothStatus.available
                                text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled
                                                                  ? "bluetooth" : "bluetooth_disabled"
                                iconSize: BarGeometry.iconSize
                                color: BluetoothStatus.enabled ? (rightSidebarButton.hovered
                                                                  ? statusPalette.statePalette.onHover :
                                                                    statusPalette.statePalette.on) :
                                                                 rightSidebarButton.colText
                            }
                        }
                    }

                    SysTray {
                        visible: root.useShortenedForm === 0
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: BarGeometry.buttonSize
                        invertSide: Config?.options.bar.bottom
                    }

                    BatteryIndicator {
                        visible: root.useShortenedForm < 2 && Battery.available
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
                BarGroup {
                    id: utilitySection
                    glass: false
                    padding: 0
                    Layout.alignment: Qt.AlignVCenter
                    UtilButtons {
                        id: utilityButtons
                        visible: Config.options.bar.verbose && root.useShortenedForm === 0
                        Layout.alignment: Qt.AlignVCenter
                    }
                    LaptopMonitorButton {
                        visible: !Battery.available
                        statePalette: utilityButtons.statePalette
                        Layout.alignment: Qt.AlignVCenter
                    }
                    GlassButton {
                        statePalette: utilityButtons.statePalette
                        Layout.alignment: Qt.AlignVCenter
                        toggled: GlobalStates.wallpaperSelectorOpen
                        onClicked: {
                            if (!GlobalStates.wallpaperSelectorOpen) {
                                Wallpapers.searchQuery = "";
                                Wallpapers.setDirectory(Wallpapers.defaultFolder.toString());
                            }
                            GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen;
                        }
                        GlassIcon {
                            text: "wallpaper"
                            iconSize: BarGeometry.iconSize
                        }
                    }
                }

                // Weather
                Loader {
                    Layout.leftMargin: 4
                    active: Config.options.bar.weather.enable
                    visible: active

                    sourceComponent: BarGroup {
                        WeatherBar {}
                    }
                }
            }
        }
    }
}
