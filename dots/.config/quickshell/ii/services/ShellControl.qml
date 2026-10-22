import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Deployment control. A fresh generation token distinguishes a successful reload
// from the old instance answering IPC after a failed reload.
Scope {
    id: root
    readonly property double generation: Date.now()
    function findStats(item): var {
        if (!item) return null;
        if (item.objectName === "systemStats") return item;
        for (const child of item.children ?? []) {
            const found = findStats(child);
            if (found) return found;
        }
        return null;
    }
    function barHealth(): var {
        return GlobalFocusGrab.persistent.filter(window => window?.backingWindowVisible).map(window => {
            const stats = findStats(window.contentItem);
            return stats ? { screen: window.screen?.name, visible: stats.visible && stats.opacity > 0,
                width: stats.width, height: stats.height } : null;
        }).filter(value => value !== null);
    }
    IpcHandler {
        target: "shellControl"
        function health(): string {
            return JSON.stringify({ pid: Quickshell.processId, generation: root.generation,
                watching: Quickshell.watchFiles, locked: GlobalStates.screenLocked,
                screens: Quickshell.screens.map(screen => screen.name), bars: root.barHealth() });
        }
        function setWatching(enabled: bool): void { Quickshell.watchFiles = enabled; }
        function reload(): void { Quickshell.reload(false); }
    }
}
