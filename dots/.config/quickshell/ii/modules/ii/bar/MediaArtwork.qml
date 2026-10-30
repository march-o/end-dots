import QtQuick
import qs.modules.common.widgets

// Loading state must not remove the cover's layout slot or hide a retained image.
Item {
    id: root
    property url source
    property size sourceSize: Qt.size(52, 52)
    property color fallbackColor: "white"
    property real fallbackSize: 21
    property bool hasImage: false
    readonly property int status: artwork.status
    readonly property bool fallbackVisible: fallback.visible

    StyledImage {
        id: artwork
        anchors.fill: parent
        source: root.source
        sourceSize: root.sourceSize
        fillMode: Image.PreserveAspectCrop
        opacity: 1
        visible: root.hasImage
    }
    Connections {
        target: artwork
        function onStatusChanged() {
            if (artwork.status === Image.Ready) root.hasImage = true
            else if (artwork.status === Image.Null || artwork.status === Image.Error) root.hasImage = false
        }
    }
    MaterialSymbol {
        id: fallback
        anchors.centerIn: parent
        visible: !root.hasImage
        text: "music_note"
        iconSize: root.fallbackSize
        color: root.fallbackColor
    }
}
