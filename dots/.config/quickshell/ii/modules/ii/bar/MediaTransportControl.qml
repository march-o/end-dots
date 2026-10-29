import QtQuick

// Native Spotify controls stay independent of the slower speaker/status process.
// Pair only after the cloud confirms this room and both players share a track.
Item {
    id: root
    property var nativePlayer: null
    property var room: ({})
    property var confirmedPlayer: null
    property int revision: 0
    property var requestedPlaying: null
    property int confirmationTimeout: 15000
    readonly property var player: enabled && room.active && room.available
        && room.connected === true && confirmedPlayer === nativePlayer ? nativePlayer : null
    signal dispatched()

    function trackId(uri) {
        return String(uri ?? "").match(/(?:\/|:)track(?:\/|:)([A-Za-z0-9]+)/)?.[1] ?? ""
    }
    function invalidate() {
        confirmedPlayer = null
        requestedPlaying = null
        freshness.stop()
    }
    onNativePlayerChanged: invalidate()

    function acceptSnapshot(snapshot, startedRevision) {
        // A poll begun before a click must not rewind native playback or revoke
        // its session pairing with an older track snapshot.
        if (startedRevision !== revision) return false
        if (!snapshot.active || !snapshot.available || snapshot.connected !== true || !nativePlayer?.canControl) {
            invalidate()
            return true
        }
        const nativeId = trackId(nativePlayer.metadata?.["xesam:url"])
        if (confirmedPlayer === nativePlayer || (nativeId && nativeId === trackId(snapshot.uri))) {
            confirmedPlayer = nativePlayer
            freshness.restart()
        }
        return true
    }
    function toggle() {
        if (!player) return false
        return dispatch((requestedPlaying ?? player.isPlaying) ? "pause" : "play")
    }
    function dispatch(action, value) {
        const target = player
        if (!target || !target.canControl) return false
        if ((action === "play" && !target.canPlay) || (action === "pause" && !target.canPause)
            || (action === "next" && !target.canGoNext) || (action === "previous" && !target.canGoPrevious)
            || (action === "seek" && !(target.canSeek && target.positionSupported))) return false
        if (!["play", "pause", "next", "previous", "seek"].includes(action)) return false
        revision++
        if (action === "play") { requestedPlaying = true; target.play() }
        else if (action === "pause") { requestedPlaying = false; target.pause() }
        else if (action === "next") target.next()
        else if (action === "previous") target.previous()
        else target.position = value
        reconcile.restart()
        dispatched()
        return true
    }
    Connections {
        target: root.player
        function onIsPlayingChanged() {
            if (root.player?.isPlaying === root.requestedPlaying) root.requestedPlaying = null
        }
    }
    Timer { id: freshness; interval: root.confirmationTimeout; onTriggered: root.invalidate() }
    // This is click intent for repeated toggles, never a displayed playback state.
    Timer { id: reconcile; interval: 2000; onTriggered: root.requestedPlaying = null }
}
