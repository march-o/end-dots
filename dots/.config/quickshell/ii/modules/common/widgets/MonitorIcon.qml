import qs.services

// Shared hardware identity for the overview, workspace bar, and future widgets.
MaterialSymbol {
    property string monitorName: ""
    readonly property bool isLaptop: HyprlandData.isLaptopMonitor(monitorName)
    text: isLaptop ? "laptop_mac" : "desktop_windows"
}
