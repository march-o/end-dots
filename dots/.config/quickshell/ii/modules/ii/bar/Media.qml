pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Item {
    id: root
    readonly property MprisPlayer spotifyPlayer: Mpris.players.values.find(p => p.dbusName?.toLowerCase().includes("spotify")) ?? null
    readonly property MprisPlayer activePlayer: spotifyPlayer ?? MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property bool canChangeVolume: !!(activePlayer?.volumeSupported && activePlayer?.canControl)
    readonly property real volumeLevel: Math.max(0, Math.min(1, activePlayer?.volume ?? 0))
    property Item glassFrame
    property bool expanded: false
    property real expansionProgress: expanded ? 1 : 0
    Behavior on expansionProgress { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    WallpaperIconColor { id: localColors; target: root }
    readonly property var iconStates: localColors.statePalette
    readonly property var textStates: localColors.textStatePalette
    Layout.preferredHeight: 30
    Layout.alignment: Qt.AlignVCenter
    Layout.minimumWidth: 100
    implicitWidth: 240
    implicitHeight: 30
    function setVolume(value) { if (canChangeVolume) activePlayer.volume = Math.max(0, Math.min(1, value)) }
    function closeCard() { expanded = false; openTimer.stop(); closeTimer.stop() }
    function openSpotifyWorkspace() {
        root.closeCard()
        spotifyWorkspace.running = true
    }
    Process {
        id: spotifyWorkspace
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const monitor = JSON.parse(text).find(m => m.focused)
                    // Opening the cover must not toggle an already visible Spotify away.
                    if (monitor && monitor.specialWorkspace?.name !== "special:spotify")
                        Hyprland.dispatch('hl.dsp.workspace.toggle_special("spotify")')
                } catch (e) {
                    console.warn("Unable to open Spotify workspace:", e)
                }
            }
        }
    }
    Timer { id: openTimer; interval: 180; onTriggered: root.expanded = true }
    Timer { id: closeTimer; interval: 350; onTriggered: { if (!nameHover.hovered && !card.hovered) root.expanded = false } }
    RowLayout {
        opacity: 1 - root.expansionProgress
        // Preserve layout during the crossfade instead of rebuilding it on return.
        enabled: !root.expanded && root.expansionProgress < 0.01
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        spacing: 8
        StyledImage {
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Open Spotify workspace"
            Accessible.onPressAction: root.openSpotifyWorkspace()
            Keys.onReturnPressed: root.openSpotifyWorkspace()
            Keys.onEnterPressed: root.openSpotifyWorkspace()
            Keys.onSpacePressed: root.openSpotifyWorkspace()
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openSpotifyWorkspace()
            }
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            source: root.activePlayer?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
        }
        StyledText {
            HoverHandler {
                id: nameHover
                onHoveredChanged: {
                    if (hovered) { closeTimer.stop(); openTimer.restart() }
                    else { openTimer.stop(); closeTimer.restart() }
                }
            }
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            text: root.cleanedTitle
            color: root.activePlayer?.isPlaying ? root.textStates.on : root.textStates.off
        }
        GlassButton {
            statePalette: root.iconStates
            implicitWidth: 25
            implicitHeight: 30
            enabled: root.activePlayer?.canGoPrevious ?? false
            onClicked: root.activePlayer?.previous()
            GlassIcon { text: "skip_previous"; iconSize: 21 }
        }
        GlassButton {
            statePalette: root.iconStates
            implicitWidth: 25
            implicitHeight: 30
            toggled: root.activePlayer?.isPlaying ?? false
            enabled: root.activePlayer?.canControl ?? false
            onClicked: root.activePlayer?.togglePlaying()
            GlassIcon { text: root.activePlayer?.isPlaying ? "pause" : "play_arrow"; iconSize: 22 }
        }
        GlassButton {
            statePalette: root.iconStates
            implicitWidth: 25
            implicitHeight: 30
            enabled: root.activePlayer?.canGoNext ?? false
            onClicked: root.activePlayer?.next()
            GlassIcon { text: "skip_next"; iconSize: 21 }
        }
    }
    MediaCard {
        id: card
        media: root
        x: (root.width - width) / 2
        y: -5
        width: 320
        height: 438
        opacity: root.expansionProgress
        visible: opacity > 0.01
        scale: 0.92 + root.expansionProgress * 0.08
        transformOrigin: Item.Top
        onHoveredChanged: { if (hovered) { root.expanded = true; closeTimer.stop() } else closeTimer.restart() }
    }
}
