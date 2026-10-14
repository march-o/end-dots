import QtQuick
import qs.modules.common

// Animate content inside a stationary surface, so glass can sample the wallpaper
// at its actual screen position throughout entry, exit, and direction reversals.
Item {
    id: root
    property bool shown: false
    property string edge: "top"
    property real progress: 0
    property bool ready: false
    // Item.visible includes ancestor visibility. Keep the window lifecycle
    // independent, otherwise hiding a native surface prevents it reopening.
    readonly property bool presented: shown || progress > 0
    readonly property alias maskItem: movingContent
    default property alias contentData: movingContent.data
    visible: presented

    function updateTarget() { progress = shown ? 1 : 0; }
    onShownChanged: if (ready) Qt.callLater(updateTarget)
    Component.onCompleted: { ready = true; Qt.callLater(updateTarget); }

    Behavior on progress {
        NumberAnimation {
            duration: root.shown ? Appearance.animation.menuDecel.duration : Appearance.animation.elementMoveExit.duration
            easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    Item {
        id: movingContent
        width: root.width
        height: root.height
        x: (1 - root.progress) * (root.edge === "right" ? width : root.edge === "left" ? -width : 0)
        y: (1 - root.progress) * (root.edge === "bottom" ? height : root.edge === "top" ? -height : 0)
        enabled: root.shown
    }
}
