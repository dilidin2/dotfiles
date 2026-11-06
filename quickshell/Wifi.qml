import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Pannello Wi-Fi 240×170: esce dalla CIMA del dock (bordo inferiore a
// contatto), cresce verso l'ALTO con molla, raccordi CONCAVI in basso
// (stesso pattern smin del dock). Stessa larghezza del dock → i fillet
// si innestano puliti sui bordi del dock.
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    maxW: 192                  // i fillet (±20) finiscono a [44,276], dentro il dock
    maxH: Theme.wifiH          // 170
    growY: "up"
    growX: "none"
    attach: "bottom"
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel

    panelNamespace: "wifi_panel"
    anchorLeft: true
    anchorTop: true
    // Centrato sul dock: pannello a [64,256], fillet a [44,276] (4px dentro).
    // Bordo inferiore alla cima del dock (y=380). Il MorphPanel compensa.
    marginLeft: 64
    marginTop: 210

    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── stato rete ───────────────────────────────────────────────────
    property var currentNet: null          // {ssid, signal}
    property var networks: []             // [{ssid,signal,security,saved}]
    // flyout a destra: ssid + modalità (connect | disconnect)
    property bool   flyoutOpen: false
    property string flyoutSsid: ""
    property string flyoutMode: "connect"

    // ── scan (ogni 8s, solo quando aperto) ───────────────────────────
    function parse(text) {
        let d
        try { d = JSON.parse(text) } catch (e) { return }
        root.currentNet = d.current || null
        root.networks = d.networks || []
    }

    property Process proc: Process {
        id: proc
        command: ["/usr/bin/python3", Quickshell.shellPath("scripts/wifi_scan.py")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }
    property Timer scanTimer: Timer {
        interval: 8000
        repeat: true
        running: root.open
        onTriggered: proc.running = true
    }
    // scan immediato in apertura; chiudendo chiudi anche il flyout
    onOpenChanged: {
        if (root.open) proc.running = true
        else root.flyoutOpen = false
    }

    // apre il flyout a destra in modalità connect (rete della lista)
    function openFlyoutConnect(ssid) {
        root.flyoutSsid = ssid
        root.flyoutMode = "connect"
        root.flyoutOpen = true
    }
    // apre il flyout in modalità disconnect (rete corrente)
    function openFlyoutDisconnect() {
        if (!root.currentNet) return
        root.flyoutSsid = root.currentNet.ssid
        root.flyoutMode = "disconnect"
        root.flyoutOpen = true
    }

    function connectNet(ssid, password) {
        const args = ["nmcli", "device", "wifi", "connect", ssid]
        if (password) args.push("password", password)
        Quickshell.execDetached(args)
        // refresh dopo il tentativo
        setTimeout(() => { proc.running = true }, 1500)
    }
    function disconnectNet() {
        // come Ignis: prende il nome della connessione attiva e fa "con down"
        Quickshell.execDetached(["/bin/bash", "-c",
            "name=$(nmcli -t -f NAME,TYPE con show --active 2>/dev/null | head -1 | cut -d: -f1); "
            + "[ -n \"$name\" ] && nmcli con down \"$name\" 2>/dev/null"])
        setTimeout(() => { proc.running = true }, 1500)
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.closePanel()
    }

    // ── contenuto (240×170 fisso, ritagliato dalla forma) ───────────
    Item {
        width: root.maxW
        height: root.maxH

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── rete corrente (click → disconnetti) ─────────────────
            Rectangle {
                id: curRow
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Theme.btnR
                color: curMa.containsMouse ? Theme.active : Theme.hover

                Behavior on color { ColorAnimation { duration: Theme.hoverMs } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    IconImage {
                        implicitSize: 15
                        source: Theme.icon("wifi.svg")
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.currentNet ? root.currentNet.ssid : "Nessuna rete"
                        color: Theme.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        text: root.currentNet ? root.currentNet.signal + "%" : ""
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: curMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.currentNet ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { if (root.currentNet) root.openFlyoutDisconnect() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.active
            }

            // ── lista reti (sempre visibile: il flyout è un pannello a sè) ──
            Rectangle {
                id: listHost
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                ListView {
                    anchors.fill: parent
                    anchors.leftMargin: -4
                    anchors.rightMargin: -4
                    model: root.networks
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: listHost.width
                        height: 30
                        radius: Theme.btnR
                        color: rowMa.containsMouse ? Theme.hover : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.hoverMs } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // segnale
                            Text {
                                text: modelData.signal + ""
                                color: Theme.textDim
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            // SSID
                            Text {
                                Layout.fillWidth: true
                                text: modelData.ssid
                                color: Theme.textDim
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            // lucchetto se protetta
                            Text {
                                text: modelData.security && modelData.security !== "--"
                                       ? "🔒" : ""
                                opacity: 0.7
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openFlyoutConnect(modelData.ssid)
                        }
                    }
                }
            }
        }

    }
}
