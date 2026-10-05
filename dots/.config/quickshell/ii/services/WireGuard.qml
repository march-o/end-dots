pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Discover local NetworkManager profiles; never store VPN credentials here.
Singleton {
    id: root

    property var profiles: []
    property string selectedUuid: ""
    property string lastError: ""
    readonly property var target: profiles.find(p => p.active)
        ?? profiles.find(p => p.uuid === selectedUuid) ?? profiles[0] ?? null
    readonly property bool active: profiles.some(p => p.active)
    readonly property bool busy: toggleProcess.running
    readonly property string statusText: {
        if (busy) return "WireGuard: switching…";
        if (lastError) return "WireGuard: " + lastError;
        if (!target) return "WireGuard: no configured connections";
        return profiles.map(p => p.name + ": " + (p.active ? "On" : "Off")).join("\n")
            + "\nClick to turn " + target.name + (target.active ? " off" : " on");
    }

    function refresh() {
        if (!statusProcess.running) statusProcess.running = true;
    }

    function toggle() {
        if (busy) return;
        if (!target) {
            Quickshell.execDetached(["notify-send", "WireGuard", "Import a WireGuard profile into NetworkManager first."]);
            return;
        }
        selectedUuid = target.uuid;
        lastError = "";
        toggleProcess.exec(["nmcli", "--wait", "20", "connection",
            target.active ? "down" : "up", "uuid", target.uuid]);
    }

    Process {
        id: statusProcess
        running: true
        command: ["nmcli", "--terse", "--escape", "no", "--fields", "UUID,TYPE,DEVICE,NAME", "connection", "show"]
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const connections = [];
                for (const line of text.trim().split("\n")) {
                    const fields = line.split(":");
                    if (fields[1] !== "wireguard") continue;
                    connections.push({ uuid: fields[0], name: fields.slice(3).join(":"),
                        active: fields[2] !== "" && fields[2] !== "--" });
                }
                root.profiles = connections;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.profiles = [];
                root.lastError = "NetworkManager unavailable";
            } else if (root.lastError === "NetworkManager unavailable") {
                root.lastError = "";
            }
        }
    }

    Process {
        id: toggleProcess
        environment: ({ LC_ALL: "C" })
        stderr: StdioCollector {
            onStreamFinished: root.lastError = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (!root.lastError) root.lastError = "Could not change connection";
                Quickshell.execDetached(["notify-send", "WireGuard", root.lastError]);
            }
            root.refresh();
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
