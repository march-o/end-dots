import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The shared glass-* layer rule disables compositor animation. PanelSlide owns
// movement so the wallpaper backdrop and pointer mask follow the visible panel.
PanelWindow {
    id: root
    required property string panelName
    property bool shown: false
    property bool dismissOnFocusLoss: true
    property alias slideFrom: reveal.edge
    readonly property string layerNamespace: `quickshell:glass-${panelName}`
    default property alias panelData: reveal.contentData
    signal dismissRequested()

    visible: reveal.presented
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: layerNamespace
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: reveal.maskItem }

    function updateFocusGrab() {
        if (dismissOnFocusLoss && shown && backingWindowVisible) GlobalFocusGrab.addDismissable(root);
        else GlobalFocusGrab.removeDismissable(root);
    }
    onDismissOnFocusLossChanged: updateFocusGrab()
    // Opening can recreate the native layer surface. Register after its show
    // and focus changes settle, never while the previous surface is closing.
    // Release immediately on dismissal so the exit animation cannot hold input.
    onShownChanged: {
        if (shown) Qt.callLater(updateFocusGrab);
        else GlobalFocusGrab.removeDismissable(root);
    }
    onBackingWindowVisibleChanged: Qt.callLater(updateFocusGrab)
    Component.onDestruction: GlobalFocusGrab.removeDismissable(root)

    property Connections dismissal: Connections {
        target: GlobalFocusGrab
        function onDismissed() { if (root.dismissOnFocusLoss && root.shown) root.dismissRequested(); }
    }
    property Item slide: PanelSlide {
        id: reveal
        parent: root.contentItem
        anchors.fill: parent
        shown: root.shown
    }
}
