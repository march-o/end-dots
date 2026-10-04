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

        Layout.preferredWidth: 24
        Layout.preferredHeight: 30

        Rectangle {
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 7
            visible: button.prominent || buttonMouse.containsMouse
            color: button.prominent ? Appearance.colors.colPrimary : Appearance.colors.colLayer1Hover
            opacity: button.available ? 1 : 0.45
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: button.symbol
            fill: 1
            iconSize: button.prominent ? 18 : 19
            color: button.prominent ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            opacity: button.available ? 1 : 0.4
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
            color: Appearance.colors.colSecondaryContainer
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
                color: Appearance.colors.colOnSecondaryContainer
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
                color: Appearance.colors.colOnLayer1
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
                height: 6
                radius: 3
                color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colSecondaryContainer, 0.7)

                Rectangle {
                    width: parent.width * root.volumeLevel
                    height: parent.height
                    radius: parent.radius
                    color: Appearance.colors.colPrimary
                }
            }
            Rectangle {
                x: Math.max(6, Math.min(parent.width - width - 6, 6 + (parent.width - 12) * root.volumeLevel - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: volumeMouse.pressed ? 20 : 17
                radius: 2.5
                color: Appearance.colors.colPrimary
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
            color: Appearance.colors.colPrimary
        }
    }
}
