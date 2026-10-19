import QtQuick

// Keep interaction immediate while serializing asynchronous device writes.
Item {
    id: root
    property real observedValue: 0
    property string sourceKey: ""
    property bool available: false
    readonly property real value: pendingValue >= 0 ? pendingValue : observedValue
    property real pendingValue: -1
    property real queuedValue: -1
    property bool busy: false
    property int revision: 0
    property int sentRevision: -1
    property string sentSource: ""
    signal writeRequested(real value)

    function request(value) {
        if (!available || !Number.isFinite(value)) return;
        pendingValue = Math.max(0, Math.min(1, value));
        queuedValue = pendingValue;
        revision++;
        reconcile.stop();
        if (!busy && !throttle.running) throttle.start();
    }
    function flush() {
        if (busy || queuedValue < 0 || !available) return;
        const next = queuedValue;
        queuedValue = -1;
        sentRevision = revision;
        sentSource = sourceKey;
        busy = true;
        writeRequested(next);
    }
    function complete(ok) {
        busy = false;
        if (sentSource === sourceKey && sentRevision === revision) {
            if (!ok || Math.abs(observedValue - pendingValue) < 0.011) pendingValue = -1;
            else reconcile.restart();
        }
        if (queuedValue >= 0) throttle.restart();
    }
    function reset() {
        revision++;
        queuedValue = -1;
        pendingValue = -1;
        throttle.stop();
        reconcile.stop();
    }
    onSourceKeyChanged: reset()
    onAvailableChanged: if (!available) reset()
    onObservedValueChanged: {
        if (!busy && queuedValue < 0 && Math.abs(observedValue - pendingValue) < 0.011) {
            pendingValue = -1;
            reconcile.stop();
        }
    }
    Timer { id: throttle; interval: 40; onTriggered: root.flush() }
    Timer { id: reconcile; interval: 1500; onTriggered: root.pendingValue = -1 }
}
