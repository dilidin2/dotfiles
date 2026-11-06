import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Flyout Wi-Fi: spunta a DESTRA dal pannello Wi-Fi (bordo sinistro
// agganciato al bordo destro del Wi-Fi), cresce da sinistra a destra
// con la STESSA molla del pannello (MorphPanel attach:"left").
//
//  • modalità "connect"     → label + password + [Connetti | Annulla]
//  • modalità "disconnect"  → label + [Disconnetti | Annulla]
//
// I segnali vengono cablati in shell.qml al pannello Wi-Fi principale.
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    maxW: 180                  // compatto: label + password + 2 pulsanti
    maxH: 110                  // più basso del Wi-Fi, centrato su di esso
    growX: "right"
    growY: "none"
    attach: "left"
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel

    panelNamespace: "wifi_flyout"
    anchorLeft: true
    anchorTop: true
    // Bordo sinistro agganciato al bordo DESTRO del Wi-Fi (x=256), centrato
    // verticalmente sul Wi-Fi (y=210..380, centro 295 → cima 240).
    marginLeft: 256
    marginTop: 240

    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── stato ────────────────────────────────────────────────────────
    property string ssid: ""
    property string mode: "connect"   // connect | disconnect

    signal connectRequested(string ssid, string password)
    signal disconnectRequested()
    signal cancelRequested()

    // al primo focus (apertura) svuota il campo e lo attiva
    onOpenChanged: if (root.open) { pwField.text = ""; pwField.forceActiveFocus() }

    Shortcut {
        sequence: "Escape"
        onActivated: root.cancelRequested()
    }

    // ── contenuto (220×170) ──────────────────────────────────────────
    Item {
        width: root.maxW
        height: root.maxH

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── rete ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                IconImage { implicitSize: 16; source: Theme.icon("wifi.svg") }
                Text {
                    Layout.fillWidth: true
                    text: root.ssid
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            // ── password (solo connect) ─────────────────────────────
            TextField {
                id: pwField
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                visible: root.mode === "connect"
                placeholderText: "Password"
                echoMode: TextField.Password
                color: Theme.text
                font.pixelSize: 13
                onAccepted: root.connectRequested(root.ssid, pwField.text)
                background: Rectangle {
                    color: Theme.bgSolid
                    radius: Theme.btnR
                }
            }

            // ── connect: [Connetti | Annulla] ────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.mode === "connect"

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.btnR
                    color: connMa.containsMouse ? Theme.activeHi : Theme.active
                    Text {
                        anchors.centerIn: parent
                        text: "Connetti"
                        color: Theme.bgSolid
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: connMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.connectRequested(root.ssid, pwField.text)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.btnR
                    color: annCma.containsMouse ? Theme.hover : Theme.bgSolid
                    Text {
                        anchors.centerIn: parent
                        text: "Annulla"
                        color: Theme.text
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: annCma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelRequested()
                    }
                }
            }

            // ── disconnect: [Disconnetti | Annulla] ──────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.mode === "disconnect"

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.btnR
                    color: discMa.containsMouse ? Theme.activeHi : Theme.active
                    Text {
                        anchors.centerIn: parent
                        text: "Disconnetti"
                        color: Theme.bgSolid
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: discMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.disconnectRequested()
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.btnR
                    color: annDma.containsMouse ? Theme.hover : Theme.bgSolid
                    Text {
                        anchors.centerIn: parent
                        text: "Annulla"
                        color: Theme.text
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: annDma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelRequested()
                    }
                }
            }
        }
    }
}
