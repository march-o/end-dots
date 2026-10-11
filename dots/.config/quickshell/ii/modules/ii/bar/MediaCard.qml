pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property Item media
    readonly property bool hovered: cardHover.hovered
    property bool devicesOpen: false
    property var connectDevices: ["Living Room"]
    property string connectSource: ""
    property string connectError: ""
    property string requestedSource: ""
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
        if (connect.running) return
        root.requestedSource = "Living Room"
        root.connectError = ""
        connect.command = ["python3", Quickshell.shellPath("scripts/media/spotify-connect.py"), "play-room"]
        connect.running = true
    }
    Process {
        id: connect
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.ok) { root.connectDevices = data.devices; root.connectSource = data.source; root.connectError = "" }
                    else root.connectError = data.error
                } catch (e) { root.connectError = "Device connection unavailable" }
                if (root.connectError && root.requestedSource) root.devicesOpen = true
                if (root.connectError || root.connectSource === root.requestedSource) root.requestedSource = ""
            }
        }
    }
    Timer { interval: root.requestedSource ? 3000 : 15000; running: root.visible; repeat: true; onTriggered: root.refreshDevices() }
    onDevicesOpenChanged: {
        if (devicesOpen) {
            if (deviceScroll.contentItem) deviceScroll.contentItem.contentY = 0;
            refreshDevices();
        }
    }
    readonly property var localStreams: Audio.outputAppNodes.filter(n => /spotify/i.test(Audio.appNodeDisplayName(n)))
    readonly property bool localPlayback: localStreams.length > 0
    property list<real> levels: []
    property real phase: 0
    // Share the bar's palette-colored glass and backdrop-bound contrast checks.
    readonly property color textColor: BarGlassPalette.glassTextTone
    readonly property var statePalette: BarGlassPalette.islandButtonColors(BarGlassPalette.glassTint)
    readonly property var textStatePalette: BarGlassPalette.islandButtonColors(BarGlassPalette.glassTint, 4.5)
    onVisibleChanged: { if (!visible) { devicesOpen = false; levels = [] } else refreshDevices() }
    Timer { interval: 33; running: root.visible && root.media.activePlayer?.isPlaying; repeat: true; onTriggered: root.phase += 0.055 }
    Process {
        running: root.visible && root.localPlayback && !!root.media.activePlayer?.isPlaying
        command: ["cava", "-p", Quickshell.shellPath("scripts/cava/media_card_config.txt")]
        stdout: SplitParser { onRead: data => { root.levels = data.split(";").map(Number).filter(v => Number.isFinite(v)) } }
    }
    component DeviceChoice: RippleButton {
        id: choice
        property string label
        property string symbol: "speaker"
        property bool selected: false
        readonly property var choiceStates: root.textStatePalette
        readonly property color foreground: selected
            ? (hovered ? choiceStates.onHover : choiceStates.on)
            : (hovered ? choiceStates.offHover : choiceStates.off)
        Layout.fillWidth: true
        implicitHeight: 40
        buttonRadius: 12
        colBackground: "transparent"
        colBackgroundHover: "transparent"
        colBackgroundToggled: "transparent"
        colBackgroundToggledHover: "transparent"
        rippleEnabled: false
        contentItem: RowLayout {
            spacing: 12
            MaterialSymbol { text: choice.symbol; iconSize: 22; color: choice.foreground }
            StyledText { Layout.fillWidth: true; text: choice.label; elide: Text.ElideRight; color: choice.foreground; font.pixelSize: 13 }
            MaterialSymbol { visible: choice.selected; text: "check"; iconSize: 18; color: choice.foreground }
        }
    }
    Item {
        id: face
        anchors.fill: parent
        anchors.margins: 2
        HoverHandler { id: cardHover; enabled: root.visible && root.media.expanded }
        Item {
            x: 8; y: parent.height - 100; width: parent.width - 16; height: 90
            WaveVisualizer {
                points: root.localPlayback ? root.levels : Array.from({length: 24}, (_, i) => 70 + 45 * Math.sin(root.phase + i * 0.32))
                live: root.media.activePlayer?.isPlaying ?? false
                color: root.statePalette.on
                maxVisualizerValue: root.localPlayback ? 1000 : 200
                opacity: 0.55
            }
        }
        Canvas {
            id: bassRings
            anchors.fill: parent
            readonly property real bass: root.localPlayback && root.levels.length > 3
                ? Math.min(1, (root.levels[0] + root.levels[1] + root.levels[2]) / 3000) : 0.15
            Connections { target: root; function onPhaseChanged() { bassRings.requestPaint() } }
            onBassChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!root.media.activePlayer?.isPlaying) return
                const col = root.statePalette.on
                for (let i = 0; i < 3; ++i) {
                    const radius = 92 + i * 24 + bass * 12 + Math.sin(root.phase * 0.8 - i * 0.5) * 4
                    ctx.beginPath()
                    ctx.arc(width * 0.40, height * 0.40, radius, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, (0.075 + bass * 0.08) * (1 - i * 0.22))
                    ctx.lineWidth = 1.2
                    ctx.stroke()
                }
            }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8
            visible: !root.devicesOpen
            RowLayout {
                Layout.fillWidth: true
                StyledText { id: headerText; text: "NOW PLAYING"; font.pixelSize: 10; font.letterSpacing: 1.5; color: root.textColor; Layout.fillWidth: true }
                MaterialSymbol { id: activityGlyph; text: "graphic_eq"; iconSize: 18; color: root.statePalette.on }
                GlassButton {
                    id: closeControl
                    statePalette: root.statePalette
                    implicitHeight: 22
                    implicitWidth: 22
                    onClicked: root.media.closeCard()
                    GlassIcon { text: "close"; iconSize: 18 }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    id: artwork
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Open Spotify workspace"
                    Accessible.onPressAction: root.media.openSpotifyWorkspace()
                    Keys.onReturnPressed: root.media.openSpotifyWorkspace()
                    Keys.onEnterPressed: root.media.openSpotifyWorkspace()
                    Keys.onSpacePressed: root.media.openSpotifyWorkspace()
                    Layout.preferredWidth: 220.8
                    Layout.maximumWidth: 220.8
                    Layout.minimumWidth: 220.8
                    Layout.preferredHeight: 220.8
                    radius: 16
                    color: "transparent"
                    scale: root.media.activePlayer?.isPlaying ? (root.localPlayback && root.levels.length > 3
                        ? 1 + Math.min(0.018, (root.levels[0] + root.levels[1] + root.levels[2]) / 3000 * 0.018)
                        : 1 + Math.sin(root.phase * 0.7) * 0.004) : 1
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: Rectangle { width: artwork.width; height: artwork.height; radius: artwork.radius } }
                    StyledImage { anchors.fill: parent; source: root.media.activePlayer?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop }
                    MaterialSymbol { anchors.centerIn: parent; visible: !root.media.activePlayer?.trackArtUrl; text: "music_note"; iconSize: 60; color: root.statePalette.off }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.media.openSpotifyWorkspace()
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3
                    MediaVolumeSlider {
                        id: volumeSlider
                        Layout.alignment: Qt.AlignHCenter
                        vertical: true
                        available: root.media.canChangeVolume
                        value: root.media.volumeLevel
                        statePalette: root.statePalette
                        Layout.preferredHeight: 180.8
                        onMoved: volume => root.media.setVolume(volume)
                    }
                    StyledText { id: volumeText; Layout.alignment: Qt.AlignHCenter; text: root.media.canChangeVolume ? Math.round(root.media.volumeLevel * 100) + "%" : "—"; font.pixelSize: 10; color: root.textColor }
                    MaterialSymbol { id: volumeGlyph; Layout.alignment: Qt.AlignHCenter; text: "volume_up"; iconSize: 18; color: root.statePalette.off }
                }
            }
            StyledText { id: titleText; Layout.fillWidth: true; text: root.media.cleanedTitle; elide: Text.ElideRight; font.pixelSize: 17; font.weight: Font.DemiBold; color: root.textColor }
            StyledText { id: artistText; Layout.fillWidth: true; text: root.media.activePlayer?.trackArtist ?? ""; elide: Text.ElideRight; font.pixelSize: 12; color: root.textColor }
            MediaProgress {
                id: songProgress
                player: root.media.activePlayer
                foreground: root.textColor
                accent: root.statePalette.on
                active: root.visible && !!root.media.activePlayer?.isPlaying
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                GlassButton {
                    id: previousControl
                    statePalette: root.statePalette
                    enabled: root.media.activePlayer?.canGoPrevious ?? false
                    onClicked: root.media.activePlayer?.previous()
                    GlassIcon { text: "skip_previous"; iconSize: 26 }
                }
                GlassButton {
                    id: pauseControl
                    statePalette: root.statePalette
                    toggled: root.media.activePlayer?.isPlaying ?? false
                    enabled: root.media.activePlayer?.canControl ?? false
                    onClicked: root.media.activePlayer?.togglePlaying()
                    GlassIcon { text: root.media.activePlayer?.isPlaying ? "pause" : "play_arrow"; iconSize: 32 }
                }
                GlassButton {
                    id: nextControl
                    statePalette: root.statePalette
                    enabled: root.media.activePlayer?.canGoNext ?? false
                    onClicked: root.media.activePlayer?.next()
                    GlassIcon { text: "skip_next"; iconSize: 26 }
                }
                Item { Layout.fillWidth: true }
                Item {
                    implicitWidth: livingRoomControl.implicitWidth
                    implicitHeight: livingRoomControl.implicitHeight
                    GlassButton {
                        id: livingRoomControl
                        anchors.fill: parent
                        statePalette: root.statePalette
                        toggled: root.connectSource === "Living Room"
                        enabled: !connect.running
                        Accessible.name: "Play in Living Room"
                        onClicked: root.playInLivingRoom()
                        GlassIcon { text: "speaker"; iconSize: 24 }
                    }
                    PopupToolTip {
                        extraVisibleCondition: livingRoomControl.hovered
                        anchorEdges: Edges.Bottom
                        text: "Play in Living Room"
                    }
                }
                GlassButton {
                    id: deviceControl
                    statePalette: root.statePalette
                    toggled: root.devicesOpen
                    onClicked: root.devicesOpen = !root.devicesOpen
                    GlassIcon { text: "devices"; iconSize: 24 }
                }
            }
            StyledText { id: footerText; text: root.requestedSource ? "CONNECTING · " + root.requestedSource.toUpperCase() : root.localPlayback ? "LIVE AUDIO · LOCAL OUTPUT" : "AMBIENT · " + (root.connectSource || "REMOTE PLAYBACK").toUpperCase(); font.pixelSize: 8; font.letterSpacing: 0.6; color: root.textColor }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            radius: 18
            visible: root.devicesOpen
            color: "transparent"
            ScrollView {
                id: deviceScroll
                anchors.fill: parent
                anchors.margins: 18
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: deviceScroll.availableWidth
                    spacing: 10
                StyledText { id: devicesTitle; text: "Playback devices"; font.pixelSize: 20; color: root.textColor }
                StyledText { id: connectHeading; text: "SPOTIFY CONNECT"; font.pixelSize: 10; color: root.textColor }
                Repeater {
                    model: root.connectDevices
                    delegate: DeviceChoice {
                        required property string modelData
                        label: modelData
                        selected: root.connectSource === modelData
                        symbol: /pc|computer|laptop/i.test(modelData) ? "computer" : /phone/i.test(modelData) ? "smartphone" : "speaker"
                        enabled: !connect.running
                        onClicked: { if (root.connectSource !== modelData) root.selectDevice(modelData) }
                    }
                }
                StyledText { Layout.fillWidth: true; visible: connect.running || !!root.connectError || !!root.requestedSource; text: root.connectError || (root.requestedSource ? "Switching to " + root.requestedSource + "…" : "Refreshing devices…"); wrapMode: Text.Wrap; font.pixelSize: 11; color: root.textColor }
                StyledText { id: outputsHeading; text: "THIS COMPUTER"; font.pixelSize: 10; color: root.textColor }
                Repeater {
                    model: Audio.outputDevices
                    delegate: DeviceChoice {
                        required property var modelData
                        label: Audio.friendlyDeviceName(modelData)
                        symbol: "volume_up"
                        selected: Audio.sink === modelData
                        onClicked: Audio.setDefaultSink(modelData)
                    }
                }
                Item { Layout.fillHeight: true }
                DeviceChoice {
                    label: "Refresh devices"
                    symbol: "refresh"
                    enabled: !connect.running
                    onClicked: root.refreshDevices()
                }
                StyledText { Layout.fillWidth: true; text: "Spotify Connect"; font.pixelSize: 11; color: root.textColor; horizontalAlignment: Text.AlignHCenter }
                DeviceChoice {
                    label: "Back to music"
                    symbol: "arrow_back"
                    onClicked: root.devicesOpen = false
                }
                }
            }
        }
    }
}
