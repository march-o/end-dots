pragma Singleton
import QtQuick

QtObject {
    // Opt-in palette inheritance for glass panels; other surfaces keep Appearance.
    function forItem(item) {
        let ancestor = item;
        while (ancestor) {
            if (ancestor.glassColors) return ancestor.glassColors;
            ancestor = ancestor.parent;
        }
        return Appearance.colors;
    }
    function m3ForItem(item) {
        let ancestor = item;
        while (ancestor) {
            if (ancestor.glassM3Colors) return ancestor.glassM3Colors;
            ancestor = ancestor.parent;
        }
        return Appearance.m3colors;
    }
    function isGlass(item) {
        let ancestor = item;
        while (ancestor) {
            if (ancestor.glassColors) return true;
            ancestor = ancestor.parent;
        }
        return false;
    }
}
