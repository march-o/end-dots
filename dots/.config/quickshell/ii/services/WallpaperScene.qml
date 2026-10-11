pragma Singleton
import QtQuick

// Share the rendered geometry rather than reimplementing wallpaper parallax.
QtObject {
    id: root
    property var images: ({})
    function registerImage(screenName, image) {
        if (!screenName) return;
        const next = Object.assign({}, root.images);
        next[screenName] = image;
        root.images = next;
    }
    function unregisterImage(screenName, image) {
        if (root.images[screenName] !== image) return;
        const next = Object.assign({}, root.images);
        delete next[screenName];
        root.images = next;
    }
}
