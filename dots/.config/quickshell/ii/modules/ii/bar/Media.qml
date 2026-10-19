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
    readonly property var activePlayer: roomPlayback.active ? roomPlayer : (spotifyPlayer ?? MprisController.activePlayer)
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property bool canChangeVolume: !!(activePlayer?.volumeSupported && activePlayer?.canControl)
    readonly property real volumeLevel: volumeControl.value
    property var roomPlayback: ({})
    property real roomUpdatedAt: 0
    property real positionClock: Date.now()
    Timer { interval: 1000; running: root.expanded && !!root.roomPlayback.playing; repeat: true; onTriggered: root.positionClock = Date.now() }
    QtObject {
        id: roomPlayer
        readonly property string trackTitle: root.roomPlayback.title ?? ""
        readonly property string trackArtist: root.roomPlayback.artist ?? ""
        readonly property string trackArtUrl: root.roomPlayback.art || (root.spotifyPlayer?.trackTitle === trackTitle ? (root.spotifyPlayer?.trackArtUrl ?? "") : "")
        readonly property bool isPlaying: root.roomPlayback.playing ?? false
        readonly property bool canControl: !!root.roomPlayback.available
        readonly property bool canGoNext: canControl && !!root.roomPlayback.can_next
        readonly property bool canGoPrevious: canControl && !!root.roomPlayback.can_previous
        readonly property bool canSeek: canControl && !!root.roomPlayback.can_seek && length > 0
        readonly property bool volumeSupported: canControl
        readonly property real volume: root.roomPlayback.volume ?? 0
        readonly property bool lengthSupported: length > 0
        readonly property real length: root.roomPlayback.duration ?? 0
        readonly property bool positionSupported: true
        readonly property real position: Math.min(length, (root.roomPlayback.position ?? 0) + (isPlaying ? Math.max(0, root.positionClock - root.roomUpdatedAt) / 1000 : 0))
    }
    function controlRoom(action, value) {
        if (connect.running) {
            // Keep clicks made during a status poll; coalesce slider updates.
            let queue = root.pendingControls.slice()
            if (action === "volume" || action === "seek") queue = queue.filter(c => c.action !== action)
            queue.push({ action: action, value: value })
            root.pendingControls = queue
            return
        }
        root.requestedSource = "Living Room"
        root.connectError = ""
        connect.command = ["python3", Quickshell.shellPath("scripts/media/spotify-connect.py"), "room-control", action]
        if (value !== undefined) connect.command = [...connect.command, String(value)]
        connect.running = true
    }
    function togglePlayback() {
        if (roomPlayback.active) controlRoom(roomPlayback.playing ? "pause" : "play")
        else activePlayer?.togglePlaying()
    }
    function nextTrack() { if (roomPlayback.active) controlRoom("next"); else activePlayer?.next() }
    function previousTrack() { if (roomPlayback.active) controlRoom("previous"); else activePlayer?.previous() }
    function seekRoom(position) { controlRoom("seek", position) }
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
    function setVolume(value) { volumeControl.request(value) }
    MediaVolumeControl {
        id: volumeControl
        available: root.canChangeVolume
        observedValue: Math.max(0, Math.min(1, root.activePlayer?.volume ?? 0))
        sourceKey: root.roomPlayback.active ? "Living Room" : (root.activePlayer?.dbusName ?? "")
        onWriteRequested: value => {
            if (root.roomPlayback.active) {
                volumeWrite.command = ["python3", Quickshell.shellPath("scripts/media/spotify-connect.py"), "room-volume", String(value)]
                volumeWrite.running = true
            } else {
                root.activePlayer.volume = value
                volumeControl.complete(true)
            }
        }
    }
    Process {
        id: volumeWrite
        property var reply: null
        onStarted: reply = null
        stdout: StdioCollector {
            onStreamFinished: {
                try { volumeWrite.reply = JSON.parse(text) } catch (e) { volumeWrite.reply = null }
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Collectors finish during process teardown; handle the result afterward.
            Qt.callLater(() => {
                const data = volumeWrite.reply
                const ok = exitCode === 0 && data?.ok === true
                if (ok && root.roomPlayback.active) {
                    root.roomPlayback = Object.assign({}, root.roomPlayback, { volume: data.volume })
                    root.connectError = ""
                } else if (!ok) root.connectError = data?.error ?? "Could not change speaker volume"
                volumeControl.complete(ok)
            })
        }
    }
    function closeCard() { expanded = false; openTimer.stop(); closeTimer.stop() }
    property var connectDevices: ["Living Room"]
    property string connectSource: ""
    property string connectError: ""
    property string requestedSource: ""
    property bool pendingRoomPlay: false
    property var pendingControls: []
    function refreshDevices() {
        if (!connect.running) {
            connect.command = ["python3", Quickshell.shellPath("scripts/media/spotify-connect.py"), "status"]
            connect.running = true
        }
    }
    function selectDevice(source) {
        if (connect.running) return
        root.requestedSource = source
        root.connectError = ""
        connect.command = ["python3", Quickshell.shellPath("scripts/media/spotify-connect.py"), "select", source]
        connect.running = true
    }
    function playInLivingRoom() {
        if (connect.running) { root.pendingRoomPlay = true; return }
        root.requestedSource = "Living Room"
        root.connectError = ""
        connect.command = ["python3", Quickshell.shellPath("scripts/media/spotify-connect.py"), "play-room"]
        connect.running = true
    }
    readonly property bool connectBusy: connect.running
    Process {
        id: connect
        property int volumeSnapshot: -1
        onStarted: volumeSnapshot = volumeControl.pendingValue >= 0 ? -1 : volumeControl.revision
        onRunningChanged: {
            if (!running) Qt.callLater(() => {
                if (connect.running) return
                if (root.pendingRoomPlay) { root.pendingRoomPlay = false; root.playInLivingRoom() }
                else if (root.pendingControls.length) {
                    const queue = root.pendingControls.slice()
                    const control = queue.shift()
                    root.pendingControls = queue
                    root.controlRoom(control.action, control.value)
                }
            })
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.ok) {
                        root.connectDevices = data.devices; root.connectSource = data.source; root.connectError = ""
                        // A status request started before a volume write must not
                        // undo that write when its older snapshot arrives later.
                        const room = data.room ?? {}
                        if (room.active && connect.volumeSnapshot !== volumeControl.revision)
                            room.volume = root.roomPlayback.volume ?? room.volume
                        root.roomPlayback = room
                        root.roomUpdatedAt = Date.now(); root.positionClock = root.roomUpdatedAt
                    }
                    else root.connectError = data.error
                } catch (e) { root.connectError = "Device connection unavailable" }
                if (root.connectError && root.roomPlayback.active) {
                    root.roomPlayback = Object.assign({}, root.roomPlayback, { playing: false, available: false })
                    root.pendingControls = []
                }
                if (root.connectError && root.requestedSource) card.devicesOpen = true
                if (root.connectError || root.connectSource === root.requestedSource) root.requestedSource = ""
            }
        }
    }
    Timer { interval: root.roomPlayback.active ? 5000 : 15000; running: root.expanded || !!root.roomPlayback.active; repeat: true; onTriggered: root.refreshDevices() }
    Component.onCompleted: refreshDevices()
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
            onClicked: root.previousTrack()
            GlassIcon { text: "skip_previous"; iconSize: 21 }
        }
        GlassButton {
            statePalette: root.iconStates
            implicitWidth: 25
            implicitHeight: 30
            toggled: root.activePlayer?.isPlaying ?? false
            enabled: root.activePlayer?.canControl ?? false
            onClicked: root.togglePlayback()
            GlassIcon { text: root.activePlayer?.isPlaying ? "pause" : "play_arrow"; iconSize: 22 }
        }
        GlassButton {
            statePalette: root.iconStates
            implicitWidth: 25
            implicitHeight: 30
            enabled: root.activePlayer?.canGoNext ?? false
            onClicked: root.nextTrack()
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
