import QtQuick
import Quickshell
import Quickshell.Wayland
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
    property var volumeWrites: []
    MediaVolumeControl {
        id: volume
        available: true
        sourceKey: "test-speaker"
        observedValue: .37
        onWriteRequested: value => root.volumeWrites.push(value)
    }
    // This window exists only on CI's private compositor; it cannot take keyboard or pointer focus.
    PanelWindow {
        id: volumePreview
        anchors { bottom: true; right: true }
        implicitWidth: 240
        implicitHeight: 280
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        color: "transparent"
        Rectangle {
            id: preview
            anchors.fill: parent
            color: BarGlassPalette.glassTint
            radius: 16
            MediaVolumeSlider {
                id: slider
                x: 24; y: 20; height: 220
                vertical: true
                available: true
                value: volume.value
                onMoved: value => volume.request(value)
            }
            MediaVolumeSlider { x: 76; y: 38; available: true; value: 0 }
            MediaVolumeSlider { x: 76; y: 98; available: true; value: .5 }
            MediaVolumeSlider { x: 76; y: 158; available: true; value: 1 }
        }
    }
    function namedChild(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children ?? []) {
            const found = namedChild(child, name);
            if (found) return found;
        }
        return null;
    }
    function testRibGeometry() {
        const close = (a, b) => Math.abs(a - b) < .000001;
        const marker = namedChild(slider, "volumeIndicator");
        const track = namedChild(slider, "volumeTrack");
        require(marker && track, "Missing rail or current-level marker");
        for (const vertical of [true, false]) {
            slider.vertical = vertical;
            slider.width = vertical ? 36 : 144;
            for (let i = 0; i <= 20; i++) {
                const level = i / 20;
                slider.update({ x: 8 + (slider.width - 16) * level,
                    y: 8 + (slider.height - 16) * (1 - level) });
                const rib = namedChild(track, "volumeRib" + i);
                require(!!rib, "Missing endpoint/step rib " + i);
                const ribCenter = rib.mapToItem(slider, rib.width / 2, rib.height / 2);
                require(close(vertical ? marker.y + marker.height / 2 : marker.x + marker.width / 2,
                    vertical ? ribCenter.y : ribCenter.x), "Marker missed rib " + i);
                require(vertical ? rib.height === 1 : rib.width === 1, "Rib is not a hairline");
            }
            volume.reset();
            const expected = 8 + (vertical ? slider.height - 16 : slider.width - 16) * (vertical ? .63 : .37);
            require(close(vertical ? marker.y + marker.height / 2 : marker.x + marker.width / 2, expected),
                "External off-grid volume lost accurate position");
        }
        slider.vertical = true;
        slider.width = 36;
    }
    function testVolume() {
        const close = (a, b) => Math.abs(a - b) < .000001;
        for (let i = 0; i <= 100; i++) {
            const input = i / 100;
            slider.update({ x: 18, y: 8 + (slider.height - 16) * (1 - input) });
            require(close(volume.value, Math.round(i / 5) / 20), "Pointer did not snap to 5% at " + i);
        }
        slider.update({ x: 18, y: -100 });
        require(volume.value === 1, "Pointer exceeded upper bound");
        slider.step(1);
        require(volume.value === 1, "Wheel exceeded upper bound");
        slider.update({ x: 18, y: 1000 });
        require(volume.value === 0, "Pointer exceeded lower bound");
        slider.step(-1);
        require(volume.value === 0, "Wheel exceeded lower bound");
        for (let i = 1; i <= 20; i++) {
            slider.step(1);
            require(close(volume.value, i / 20), "Wheel up skipped/repeated a rib");
        }
        for (let i = 19; i >= 0; i--) {
            slider.step(-1);
            require(close(volume.value, i / 20), "Wheel down skipped/repeated a rib");
        }
        volume.reset();
        require(close(volume.value, .37), "External volume feedback was quantized");
        slider.step(1);
        require(close(volume.value, .4), "Off-grid wheel up did not reach next rib");
        volume.reset();
        slider.step(-1);
        require(close(volume.value, .35), "Off-grid wheel down did not reach next rib");
        slider.step(0);
        require(close(volume.value, .35), "Zero wheel delta changed volume");
        slider.available = false;
        slider.update({ x: 18, y: 8 }); slider.step(1);
        require(close(volume.value, .35), "Unavailable control accepted input");
        slider.available = true;
        slider.vertical = false; slider.width = 144;
        slider.update({ x: 8 + 128 * .61, y: 15 });
        require(close(volume.value, .6), "Horizontal pointer did not snap");
        slider.vertical = true; slider.width = 36;
        volume.flush();
        require(close(volumeWrites[0], .6), "Volume write lost target");
        slider.step(1);
        require(close(volume.value, .65), "In-flight write blocked immediate feedback");
        volume.observedValue = .6;
        volume.complete(true);
        require(close(volume.value, .65), "Stale acknowledgment rewound feedback");
        volume.flush();
        require(close(volumeWrites[1], .65), "Latest target was not coalesced");
        volume.observedValue = .65;
        volume.complete(true);
        require(volume.pendingValue === -1 && close(volume.value, .65), "Readback did not reconcile");
        volume.observedValue = .43;
        require(close(volume.value, .43), "External change was not synchronized");
        slider.step(1); volume.flush(); volume.complete(false);
        require(close(volume.value, .43), "Failed write did not restore observed volume");
        slider.step(1); volume.sourceKey = "other-speaker";
        require(volume.pendingValue === -1 && volume.queuedValue === -1, "Device change retained old intent");
        volume.observedValue = .65;
    }
    Component.onCompleted: {
        try {
            testRibGeometry();
            testVolume();
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
            preview.grabToImage(result => {
                if (!result.saveToFile("/work/artifacts/" + root.artifactPrefix + "media-volume-ribs.png"))
                    root.failure = "Could not capture ribbed rail volume preview";
                root.done = true;
            });
        }
    }
}
