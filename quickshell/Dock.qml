import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Dock: pannello 240×320 che esce dalla barra sinistra.
// Cresce in LARGHEZZA REALE (0 → 240) con molla; raccordi concavi a
// sinistra, angoli arrotondati a destra. Contenuto ritagliato + fade.
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    property var niri
    signal wifiRequested()
    signal musicRequested()
    signal steamMenuRequested()

    // Se si chiudono i sub-panel (wifi/flyout), sfasa la chiusura:
    // flyout → wifi → dock (non tutti insieme).
    property bool subsOpen: false
    signal staggerClose()

    function toggle() {
        if (root.open && root.subsOpen) {
            root.staggerClose()
        } else {
            root.open = !root.open
        }
    }
    function closeStaggered() {
        if (root.open && root.subsOpen) {
            root.staggerClose()
        } else {
            root.open = false
        }
    }

    maxW: Theme.dockW
    maxH: Theme.dockH
    growX: "right"
    growY: "none"
    attach: "left"
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel

    // Deve matchare la layer-rule niri per il blur (xray false):
    // ^(dock_panel|wifi_panel|music_panel|launcher|steam_menu|...)$
    panelNamespace: "dock_panel"
    anchorLeft: true
    anchorTop: true
    marginLeft: Theme.leftW
    marginTop: root.screen
                ? Math.round((root.screen.height - root.maxH) / 2)
                : 380

    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── statistiche (non visive) ─────────────────────────────────────
    SysStats { id: stats }

    // ── app nella tray del dock ──────────────────────────────────────
    readonly property var trayApps: [
        {
            proc: "steam",
            appid: "steam",
            label: "Steam",
            icon: Quickshell.iconPath("steam", "application-x-generic")
        },
        {
            proc: "obs64",
            appid: "obs",
            label: "OBS",
            icon: Theme.icon("obs.png")
        }
    ]

    readonly property var runningApps:
        root.trayApps.filter(a => stats.apps.indexOf(a.proc) >= 0)

    // ── orologio ─────────────────────────────────────────────────────
    property var now: new Date()

    readonly property string clockText: {
        const d = root.now
        const giorni = ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]
        const mesi = ["gen", "feb", "mar", "apr", "mag", "giu",
                      "lug", "ago", "set", "ott", "nov", "dic"]
        const hh = String(d.getHours()).padStart(2, "0")
        const mm = String(d.getMinutes()).padStart(2, "0")
        return giorni[(d.getDay() + 6) % 7] + " " + d.getDate() + " " +
               mesi[d.getMonth()] + " · " + hh + ":" + mm
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.closePanel()
    }

    // ── contenuto (240×320 fisso, ritagliato dalla forma) ───────────
    Item {
        width: root.maxW
        height: root.maxH

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Wi-Fi ────────────────────────────────────────────────
            Rectangle {
                id: wifiRow
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Theme.btnR
                color: wifiMa.containsMouse ? Theme.active : Theme.hover

                Behavior on color {
                    ColorAnimation { duration: Theme.hoverMs }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    IconImage {
                        implicitSize: 16
                        source: Theme.icon("wifi.svg")
                    }
                    Text {
                        Layout.fillWidth: true
                        text: stats.hasWifi ? stats.wifiSsid : "Nessuna rete"
                        color: Theme.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        text: stats.hasWifi ? stats.wifiSignal + "%" : ""
                        color: Theme.textDim
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: wifiMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.wifiRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.active
            }

            // ── app in esecuzione ───────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Repeater {
                        model: root.runningApps

                        delegate: Rectangle {
                            width: 32
                            height: 32
                            radius: Theme.btnR
                            color: appMa.containsMouse ? Theme.hover : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Theme.hoverMs }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 22
                                source: modelData.icon
                            }

                            MouseArea {
                                id: appMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton
                                            && modelData.proc === "steam") {
                                        root.steamMenuRequested()
                                    } else if (mouse.button === Qt.LeftButton) {
                                        if (root.niri)
                                            root.niri.focusApp(modelData.appid)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.runningApps.length === 0
                        text: "—"
                        color: Theme.textDim
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.active
            }

            // ── statistiche 2×2 ─────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                StatTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconSource: Theme.icon("ram.svg")
                    value: stats.ramText
                    tileColor: Theme.tileRam
                }
                StatTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconSource: Theme.icon("cpu.svg")
                    value: stats.cpuText
                    tileColor: Theme.tileCpu
                }
                StatTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconSource: Theme.icon("net.svg")
                    value: stats.netText
                    tileColor: Theme.tileNet
                }
                StatTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconSource: Theme.icon("volume.svg")
                    value: stats.volText
                    tileColor: Theme.tileVol
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.active
            }

            // ── data + ora ──────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.clockText
                color: Theme.accent
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
    }
}
