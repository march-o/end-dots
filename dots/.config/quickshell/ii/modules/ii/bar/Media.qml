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
    readonly property real volumeLevel: Math.max(0, Math.min(1, activePlayer?.volume ?? 0))
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.preferredHeight: 30
    Layout.alignment: Qt.AlignVCenter
    Layout.minimumWidth: 150
    implicitWidth: 400
    implicitHeight: 30

    function setVolume(value) {
        if (canChangeVolume)
            activePlayer.volume = Math.max(0, Math.min(1, value));
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch('hl.dsp.workspace.toggle_special("spotify")')
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 8

        Rectangle {
            id: albumFrame
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

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller + 1
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                    text: root.cleanedTitle
                }
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smallest + 1
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: root.activePlayer?.trackArtist || (root.spotifyPlayer ? "Spotify" : "Media")
                }
            }

        }

        Item {
            id: volumeControl
            visible: root.canChangeVolume
            Layout.preferredWidth: visible ? (root.width < 300 ? 86 : 144) : 0
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
            visible: root.canChangeVolume
            Layout.alignment: Qt.AlignVCenter
            text: root.volumeLevel < 0.01 ? "volume_off" : root.volumeLevel < 0.5 ? "volume_down" : "volume_up"
            fill: 1
            iconSize: 18
            color: Appearance.colors.colPrimary
        }
    }
}
