import Quickshell
import Quickshell.Io
import QtQuick

// ─────────────────────────────────────────────────────────────────────
// Statistiche di sistema per il dock.
// Un solo processo Python ogni 2s produce JSON:
//   RAM, CPU (delta /proc/stat), rete (delta /proc/net/dev),
//   volume (wpctl), Wi-Fi (nmcli), app in esecuzione (ps).
// ─────────────────────────────────────────────────────────────────────
QtObject {
    id: root

    property real ramUsed: 0
    property real ramTotal: 0
    property real ramPct: 0
    property real cpu: 0
    property bool hasCpu: false
    property real netDown: 0
    property real netUp: 0
    property bool hasNet: false
    property int volume: 0
    property bool hasVol: false
    property string wifiSsid: ""
    property int wifiSignal: 0
    property bool hasWifi: false
    property var apps: []

    readonly property string ramText:
        root.ramTotal > 0
        ? root.ramUsed.toFixed(1) + "/" + Math.round(root.ramTotal) + " GB"
        : "—"

    readonly property string cpuText:
        root.hasCpu ? Math.round(root.cpu) + "%" : "—"

    readonly property string netText:
        root.hasNet
        ? "↓" + root.fmtRate(root.netDown) + " ↑" + root.fmtRate(root.netUp)
        : "—"

    readonly property string volText:
        root.hasVol ? root.volume + "%" : "—"

    function fmtRate(mbs) {
        if (mbs < 0.1)
            return Math.round(mbs * 1024) + "K"
        return mbs.toFixed(1) + "M"
    }

    function parse(text) {
        let d
        try {
            d = JSON.parse(text)
        } catch (e) {
            console.warn("stats: JSON non valido:", text)
            return
        }

        root.ramUsed  = d.ram_used  !== null && d.ram_used  !== undefined ? d.ram_used  : 0
        root.ramTotal = d.ram_total !== null && d.ram_total !== undefined ? d.ram_total : 0
        root.ramPct   = d.ram_pct   !== null && d.ram_pct   !== undefined ? d.ram_pct   : 0

        root.hasCpu = d.cpu !== null && d.cpu !== undefined
        root.cpu = root.hasCpu ? d.cpu : 0

        root.hasNet = d.net_down !== null && d.net_down !== undefined
        root.netDown = root.hasNet ? d.net_down : 0
        root.netUp = root.hasNet ? (d.net_up || 0) : 0

        root.hasVol = d.vol !== null && d.vol !== undefined
        root.volume = root.hasVol ? d.vol : 0

        root.hasWifi = !!(d.wifi_ssid && d.wifi_ssid.length > 0)
        root.wifiSsid = d.wifi_ssid || ""
        root.wifiSignal = d.wifi_signal || 0

        root.apps = d.apps || []
    }

    property Process proc: Process {
        id: proc
        command: ["/usr/bin/python3", Quickshell.shellPath("scripts/stats.py")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    property Timer timer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
