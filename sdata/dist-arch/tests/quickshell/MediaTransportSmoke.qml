import QtQuick
import Quickshell
import qs.modules.ii.bar

Scope {
    id: root
    property bool done: false
    property string failure: ""
    property string artifactPrefix: ""
    property var calls: []
    property var connected: ({ active: true, available: true, connected: true, uri: "spotify:track:TRACK" })
    function require(condition, message) {
        if (!condition) throw Error(message)
    }
    QtObject {
        id: spotify
        property var metadata: ({ "xesam:url": "https://open.spotify.com/track/TRACK" })
        property bool isPlaying: true
        property bool canControl: true
        property bool canPlay: true
        property bool canPause: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canSeek: true
        property bool positionSupported: true
        property real position: 5
        function play() { root.calls.push("play") }
        function pause() { root.calls.push("pause") }
        function next() { root.calls.push("next") }
        function previous() { root.calls.push("previous") }
    }
    MediaTransportControl {
        id: transport
        nativePlayer: spotify
        room: root.connected
        confirmationTimeout: 100
    }
    Component.onCompleted: {
        try {
            require(!transport.dispatch("next"), "Unconfirmed room used native playback")
            transport.acceptSnapshot(Object.assign({}, connected, { uri: "spotify:track:OTHER" }), 0)
            require(!transport.player, "Different Spotify track was paired")
            transport.acceptSnapshot(connected, 0)
            require(transport.player === spotify, "Matching cloud/native session was not paired")
            require(transport.toggle() && transport.toggle(), "Rapid toggles waited for a status process")
            require(calls.join(",") === "pause,play", "Rapid toggles lost click intent")
            require(transport.dispatch("next") && transport.dispatch("previous"), "Skip commands were serialized behind polling")
            require(calls.join(",") === "pause,play,next,previous", "Native actions were reordered")
            require(!transport.acceptSnapshot({ active: false }, 0), "Old status rewound a newer click")
            require(transport.player === spotify, "Stale status revoked a current session")
            require(transport.acceptSnapshot(connected, transport.revision), "Current status rejected")
            spotify.metadata = { "xesam:url": "https://open.spotify.com/track/NEXT" }
            transport.acceptSnapshot(connected, transport.revision)
            require(transport.player === spotify, "A track change lost the confirmed room pairing")
            require(transport.dispatch("seek", 12) && spotify.position === 12, "Seek did not use native playback")
            spotify.canGoNext = false
            require(!transport.dispatch("next"), "Unsupported native command was sent")
            require(!transport.dispatch("volume", .5), "Speaker volume was sent to native Spotify")
            transport.acceptSnapshot(Object.assign({}, connected, { connected: false }), transport.revision)
            require(!transport.player && !transport.toggle(), "Disconnected room bypassed reconnect")
            spotify.metadata = { "xesam:url": "https://open.spotify.com/track/TRACK" }
            transport.acceptSnapshot(connected, transport.revision)
            transport.enabled = false
            require(!transport.dispatch("pause"), "Native action overtook a device switch")
            transport.enabled = true
            transport.nativePlayer = null
            require(!transport.player, "Removed native player retained its pairing")
            transport.nativePlayer = spotify
            transport.acceptSnapshot(connected, transport.revision)
            expiry.start()
        } catch (error) { failure = String(error); done = true }
    }
    Timer {
        id: expiry
        interval: 200
        onTriggered: {
            if (transport.player) root.failure = "Stale cloud confirmation did not expire"
            root.done = true
        }
    }
}
