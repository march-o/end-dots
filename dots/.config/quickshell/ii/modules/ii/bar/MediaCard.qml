pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
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
    property var connectDevices: []
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
        connect.command = ["python3", Quickshell.shellPath("scripts/media/spotify-connect.py"), "select", source]
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
                if (root.connectError || root.connectSource === root.requestedSource) root.requestedSource = ""
            }
        }
    }
    Timer { interval: root.requestedSource ? 3000 : 15000; running: root.visible; repeat: true; onTriggered: root.refreshDevices() }
    onDevicesOpenChanged: { if (devicesOpen) refreshDevices() }
    readonly property var localStreams: Audio.outputAppNodes.filter(n => /spotify/i.test(Audio.appNodeDisplayName(n)))
    readonly property bool localPlayback: localStreams.length > 0
    property list<real> levels: []
    property real phase: 0
    property var backdropGrid: []
    function captureBackdrop() {
        if (backdropProbe.running) return
        const screen = root.QsWindow.window?.screen
        const position = root.mapToItem(null, 0, 0)
        backdropProbe.command = ["python3", Quickshell.shellPath("scripts/media/sample-card-backdrop.py"),
            String(position.x + (screen?.x ?? 0)), String(position.y + (screen?.y ?? 0)),
            String(root.width), String(root.height)]
        backdropProbe.running = true
    }
    function backgroundAt(item) {
        if (backdropGrid.length !== 384 || item.width <= 0 || item.height <= 0) return tintedBackground(BarGlassPalette.dominant)
        const position = item.mapToItem(root, 0, 0)
        const left = Math.max(0, Math.min(15, Math.floor(position.x / root.width * 16)))
        const right = Math.max(left, Math.min(15, Math.floor((position.x + item.width) / root.width * 16)))
        const top = Math.max(0, Math.min(23, Math.floor(position.y / root.height * 24)))
        const bottom = Math.max(top, Math.min(23, Math.floor((position.y + item.height) / root.height * 24)))
        let r = 0, g = 0, b = 0, count = 0
        for (let y = top; y <= bottom; y++) for (let x = left; x <= right; x++) {
            const rgb = backdropGrid[y * 16 + x]
            r += rgb[0]; g += rgb[1]; b += rgb[2]; count++
        }
        return tintedBackground(Qt.rgba(r / count / 255, g / count / 255, b / count / 255, 1))
    }
    function tintedBackground(background) {
        const alpha = Config.options.bar.showBackground ? root.media.glassTintOpacity : 0
        const tint = root.media.glassTint
        return Qt.rgba(tint.r * alpha + background.r * (1 - alpha),
            tint.g * alpha + background.g * (1 - alpha),
            tint.b * alpha + background.b * (1 - alpha), 1)
    }
    function foregroundAt(item) {
        return BarGlassPalette.readableColor([BarGlassPalette.lightestTone], backgroundAt(item), 4.5)
    }
    Process {
        id: backdropProbe
        stdout: StdioCollector {
            onStreamFinished: { try { root.backdropGrid = JSON.parse(text) } catch (e) { root.backdropGrid = [] } }
        }
        onExited: root.media.finishExpansion()
    }
    component CardColor: Item {
        required property Item target
        readonly property color sampledBackground: root.backgroundAt(target)
        readonly property var statePalette: BarGlassPalette.buttonColors(sampledBackground)
        readonly property var textStatePalette: BarGlassPalette.buttonColors(sampledBackground, 4.5)
        readonly property color textColor: root.foregroundAt(target)
    }
    CardColor { id: cardColors; target: root }
    CardColor { id: titleColors; target: titleText }
    CardColor { id: artistColors; target: artistText }
    CardColor { id: headerColors; target: headerText }
    CardColor { id: footerColors; target: footerText }
    CardColor { id: devicesTitleColors; target: devicesTitle }
    CardColor { id: connectHeadingColors; target: connectHeading }
    CardColor { id: outputsHeadingColors; target: outputsHeading }
    CardColor { id: volumeTextColors; target: volumeText }
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
        CardColor { id: choiceColors; target: choice }
        readonly property var choiceStates: choiceColors.textStatePalette
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
                color: Appearance.m3colors.m3tertiary
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
                const col = Appearance.m3colors.m3tertiary
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
                StyledText { id: headerText; text: "NOW PLAYING"; font.pixelSize: 10; font.letterSpacing: 1.5; color: headerColors.textColor; Layout.fillWidth: true }
                MaterialSymbol { id: activityGlyph; text: "graphic_eq"; iconSize: 18; color: BarGlassPalette.buttonColors(root.backgroundAt(activityGlyph)).on }
                GlassButton {
                    id: closeControl
                    statePalette: BarGlassPalette.buttonColors(root.backgroundAt(closeControl))
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
                    MaterialSymbol { anchors.centerIn: parent; visible: !root.media.activePlayer?.trackArtUrl; text: "music_note"; iconSize: 60; color: Appearance.m3colors.m3primary }
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
                        statePalette: BarGlassPalette.buttonColors(root.backgroundAt(volumeSlider))
                        Layout.preferredHeight: 180.8
                        onMoved: volume => root.media.setVolume(volume)
                    }
                    StyledText { id: volumeText; Layout.alignment: Qt.AlignHCenter; text: root.media.canChangeVolume ? Math.round(root.media.volumeLevel * 100) + "%" : "—"; font.pixelSize: 10; color: volumeTextColors.textColor }
                    MaterialSymbol { id: volumeGlyph; Layout.alignment: Qt.AlignHCenter; text: "volume_up"; iconSize: 18; color: BarGlassPalette.bestColor(root.backgroundAt(volumeGlyph)) }
                }
            }
            StyledText { id: titleText; Layout.fillWidth: true; text: root.media.cleanedTitle; elide: Text.ElideRight; font.pixelSize: 17; font.weight: Font.DemiBold; color: titleColors.textColor }
            StyledText { id: artistText; Layout.fillWidth: true; text: root.media.activePlayer?.trackArtist ?? ""; elide: Text.ElideRight; font.pixelSize: 12; color: artistColors.textColor }
            MediaProgress {
                id: songProgress
                player: root.media.activePlayer
                foreground: root.foregroundAt(songProgress)
                accent: BarGlassPalette.buttonColors(root.backgroundAt(songProgress)).on
                active: root.visible && !!root.media.activePlayer?.isPlaying
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                GlassButton {
                    id: previousControl
                    statePalette: BarGlassPalette.buttonColors(root.backgroundAt(previousControl))
                    enabled: root.media.activePlayer?.canGoPrevious ?? false
                    onClicked: root.media.activePlayer?.previous()
                    GlassIcon { text: "skip_previous"; iconSize: 26 }
                }
                GlassButton {
                    id: pauseControl
                    statePalette: BarGlassPalette.buttonColors(root.backgroundAt(pauseControl))
                    toggled: root.media.activePlayer?.isPlaying ?? false
                    enabled: root.media.activePlayer?.canControl ?? false
                    onClicked: root.media.activePlayer?.togglePlaying()
                    GlassIcon { text: root.media.activePlayer?.isPlaying ? "pause" : "play_arrow"; iconSize: 32 }
                }
                GlassButton {
                    id: nextControl
                    statePalette: BarGlassPalette.buttonColors(root.backgroundAt(nextControl))
                    enabled: root.media.activePlayer?.canGoNext ?? false
                    onClicked: root.media.activePlayer?.next()
                    GlassIcon { text: "skip_next"; iconSize: 26 }
                }
                Item { Layout.fillWidth: true }
                GlassButton {
                    id: deviceControl
                    statePalette: BarGlassPalette.buttonColors(root.backgroundAt(deviceControl))
                    toggled: root.devicesOpen
                    onClicked: root.devicesOpen = !root.devicesOpen
                    GlassIcon { text: "devices"; iconSize: 24 }
                }
            }
            StyledText { id: footerText; text: root.localPlayback ? "LIVE AUDIO · LOCAL OUTPUT" : "AMBIENT · " + (root.connectSource || "REMOTE PLAYBACK").toUpperCase(); font.pixelSize: 8; font.letterSpacing: 0.6; color: footerColors.textColor }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            radius: 18
            visible: root.devicesOpen
            color: "transparent"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10
                StyledText { id: devicesTitle; text: "Playback devices"; font.pixelSize: 20; color: devicesTitleColors.textColor }
                StyledText { id: connectHeading; text: "SPOTIFY CONNECT"; font.pixelSize: 10; color: connectHeadingColors.textColor }
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
                StyledText { Layout.fillWidth: true; visible: connect.running || !!root.connectError || !!root.requestedSource; text: root.connectError || (root.requestedSource ? "Switching to " + root.requestedSource + "…" : "Refreshing devices…"); wrapMode: Text.Wrap; font.pixelSize: 11; color: cardColors.textColor }
                StyledText { id: outputsHeading; text: "THIS COMPUTER"; font.pixelSize: 10; color: outputsHeadingColors.textColor }
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
                StyledText { Layout.fillWidth: true; text: "Spotify Connect"; font.pixelSize: 11; color: cardColors.textColor; horizontalAlignment: Text.AlignHCenter }
                DeviceChoice {
                    label: "Back to music"
                    symbol: "arrow_back"
                    onClicked: root.devicesOpen = false
                }
            }
        }
    }
}
