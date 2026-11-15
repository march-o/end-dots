import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services as Services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    objectName: "homeLighting"
    property var controller: Services.HomeLighting
    readonly property var presets: controller.presets
    spacing: BarGeometry.spacing
    function label(preset) { return preset === "__off__" ? "Off" : preset.charAt(0).toUpperCase() + preset.slice(1); }
    function icon(preset) {
        const icons = { "__off__": "power_settings_new", unwind: "bedtime", chill: "weekend",
            building: "construction", cooking: "cooking", morning: "light_mode" };
        return icons[preset] ?? "lightbulb";
    }
    Repeater {
        model: root.presets
        delegate: Item {
            id: cell
            required property string modelData
            Layout.preferredWidth: BarGeometry.buttonSize
            Layout.preferredHeight: BarGeometry.buttonSize
            Layout.alignment: Qt.AlignVCenter
            GlassButton {
                id: button
                objectName: "lightingPreset-" + cell.modelData
                anchors.fill: parent
                enabled: !root.controller.busy
                Accessible.name: "Home lighting: " + root.label(cell.modelData)
                onClicked: root.controller.select(cell.modelData)
                GlassIcon { text: root.icon(cell.modelData) }
            }
            PopupToolTip {
                parent: button
                extraVisibleCondition: button.hovered
                anchorEdges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                text: root.label(cell.modelData) + (root.controller.busy ? " — sending…"
                    : root.controller.lastError ? "\n" + root.controller.lastError
                    : root.controller.lastRequested ? "\n" + root.controller.lastRequested : "")
            }
        }
    }
    Item {
        visible: root.presets.length === 0
        Layout.preferredWidth: BarGeometry.buttonSize
        Layout.preferredHeight: BarGeometry.buttonSize
        GlassButton {
            id: refreshButton
            anchors.fill: parent
            Accessible.name: "Discover Home lighting presets"
            onClicked: root.controller.refresh()
            GlassIcon { text: "lightbulb" }
        }
        PopupToolTip {
            parent: refreshButton
            extraVisibleCondition: refreshButton.hovered
            anchorEdges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            text: root.controller.lastError || "Discovering Home lighting presets…"
        }
    }
}
