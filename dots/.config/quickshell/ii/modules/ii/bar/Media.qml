pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Item {
    id: root
    WallpaperIconColor { id: localColors; target: root }
    readonly property var iconStates: localColors.statePalette ?? BarGlassPalette.buttonColors(BarGlassPalette.dominant)
    readonly property var textStates: localColors.textStatePalette ?? BarGlassPalette.buttonColors(BarGlassPalette.dominant, 4.5)

    // Control Spotify's player volume, not the computer's PipeWire sink.
    readonly property MprisPlayer spotifyPlayer: Mpris.players.values.find(player =>
        player.dbusName?.toLowerCase().includes("spotify")) ?? null
    readonly property MprisPlayer activePlayer: spotifyPlayer ?? MprisController.activePlayer
    readonly property bool canChangeVolume: !!(activePlayer?.volumeSupported && activePlayer?.canControl)
    readonly property bool compact: width < 300
    readonly property real volumeLevel: Math.max(0, Math.min(1, activePlayer?.volume ?? 0))
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.preferredHeight: 30
    Layout.alignment: Qt.AlignVCenter
    Layout.minimumWidth: 150
    implicitWidth: 480
    implicitHeight: 30

    function setVolume(value) {
        if (canChangeVolume)
            activePlayer.volume = Math.max(0, Math.min(1, value));
    }

    component TransportButton: Item {
        id: button
        property string symbol
        property bool available: false
        property bool prominent: false
        signal activated()

        Layout.preferredWidth: 32.5
        Layout.preferredHeight: 30

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.symbol
            fill: 1
            iconSize: Appearance.font.pixelSize.large * 1.25
            color: !button.available ? localColors.mutedColor
                : button.prominent && root.activePlayer?.isPlaying
                    ? (buttonMouse.containsMouse ? root.iconStates.onHover : root.iconStates.on)
                    : (buttonMouse.containsMouse ? root.iconStates.offHover : root.iconStates.off)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (button.available)
                    button.activated();
            }
        }
    }

    MouseArea {
        id: mediaMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch('hl.dsp.workspace.toggle_special("spotify")')

        StyledToolTip {
            extraVisibleCondition: mediaMouse.containsMouse
            text: root.cleanedTitle + (root.activePlayer?.trackArtist ? "\n" + root.activePlayer.trackArtist : "")
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 6

        Rectangle {
            id: albumFrame
            visible: !root.compact
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 26
            implicitHeight: 26
            radius: 4
            color: "transparent"
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: albumFrame.width
                    height: albumFrame.height
                    radius: albumFrame.radius
                }
            }

            StyledImage {
                anchors.fill: parent
                source: root.activePlayer?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: !root.activePlayer?.trackArtUrl
                text: "graphic_eq"
                fill: 1
                iconSize: 15
                color: root.activePlayer?.isPlaying ? root.iconStates.on : root.iconStates.off
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 40
            Layout.fillHeight: true

            StyledText {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.activePlayer?.isPlaying
                    ? (mediaMouse.containsMouse ? root.textStates.onHover : root.textStates.on)
                    : (mediaMouse.containsMouse ? root.textStates.offHover : root.textStates.off)
                Behavior on color { ColorAnimation { duration: 120 } }
                elide: Text.ElideRight
                text: root.cleanedTitle
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            TransportButton {
                symbol: "skip_previous"
                available: root.activePlayer?.canGoPrevious ?? false
                onActivated: root.activePlayer?.previous()
            }
            TransportButton {
                symbol: root.activePlayer?.isPlaying ? "pause" : "play_arrow"
                available: root.activePlayer?.isPlaying
                    ? (root.activePlayer?.canPause ?? false)
                    : (root.activePlayer?.canPlay ?? false)
                prominent: true
                onActivated: root.activePlayer?.togglePlaying()
            }
            TransportButton {
                symbol: "skip_next"
                available: root.activePlayer?.canGoNext ?? false
                onActivated: root.activePlayer?.next()
            }
        }

        Item {
            id: volumeControl
            visible: root.canChangeVolume
            Layout.preferredWidth: visible ? (root.compact ? 50 : 144) : 0
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: ColorUtils.applyAlpha(root.iconStates.off, 0.35)

                Rectangle {
                    width: parent.width * root.volumeLevel
                    height: parent.height
                    radius: parent.radius
                    color: volumeMouse.containsMouse ? root.iconStates.onHover : root.iconStates.on
                }
            }
            Rectangle {
                x: Math.max(6, Math.min(parent.width - width - 6, 6 + (parent.width - 12) * root.volumeLevel - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: volumeMouse.pressed ? 18 : 15
                radius: 1.5
                color: volumeMouse.containsMouse ? root.iconStates.onHover : root.iconStates.on
            }

            MouseArea {
                id: volumeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.setVolume((mouse.x - 6) / (width - 12))
                onPositionChanged: mouse => {
                    if (pressed)
                        root.setVolume((mouse.x - 6) / (width - 12));
                }
                onWheel: wheel => {
                    root.setVolume(root.volumeLevel + (wheel.angleDelta.y > 0 ? 0.04 : -0.04));
                    wheel.accepted = true;
                }
            }
        }

        MaterialSymbol {
            visible: root.canChangeVolume && !root.compact
            Layout.alignment: Qt.AlignVCenter
            text: root.volumeLevel < 0.01 ? "volume_off" : root.volumeLevel < 0.5 ? "volume_down" : "volume_up"
            fill: 1
            iconSize: 18
            color: volumeMouse.containsMouse ? root.iconStates.onHover : root.iconStates.on
        }
    }
}
