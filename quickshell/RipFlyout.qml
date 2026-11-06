import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Flyout "Scarica brano": a DESTRA del pannello musica (stesso pattern
// del flyout "nuova playlist"). Barra per incollare un link YouTube +
// tasto Scarica: lancia `vinylrip <url> -p ~/Music`. Emite done() al
// successo (per far rescannare la libreria) e cancelRequested().
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    maxW: 300
    maxH: 220
    growX: "right"
    growY: "none"
    attach: "left"
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel

    panelNamespace: "rip_flyout"
    anchorLeft: true
    anchorTop: true
    // a destra del pannello musica (x=460), allineata in alto all'header "Brani"
    marginLeft: 460
    marginTop: 738

    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── stato ────────────────────────────────────────────────────────
    // 0 = idle · 1 = in download · 2 = ok · 3 = errore
    property int status: 0
    property string statusMsg: ""

    signal done()
    signal cancelRequested()

    function openRip() {
        root.status = 0
        root.statusMsg = ""
        urlField.text = ""
        openPanel()
    }

    onOpenChanged: if (root.open) urlField.forceActiveFocus()

    Shortcut {
        sequence: "Escape"
        onActivated: root.cancelRequested()
    }

    // ── download ──────────────────────────────────────────────────────
    // bash -c + 2>&1 per catturare anche gli errori (vinylrip li manda su
    // stderr). Il successo si riconosce da "[ExtractAudio] Destination:".
    function download() {
        const u = urlField.text.trim()
        if (!u) return
        if (root.status === 1) return        // già in corso
        root.status = 1
        root.statusMsg = "Scaricando…"
        ripProc.exec(["/bin/bash", "-c",
                      "vinylrip '" + u + "' -p ~/Music 2>&1"])
    }
    Process {
        id: ripProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = String(ripProc.stdout.data)
                if (out.match(/\[ExtractAudio\] Destination:/)) {
                    root.status = 2
                    root.statusMsg = "Fatto! ✓  è in ~/Music"
                    root.done()
                } else {
                    root.status = 3
                    const lines = out.split("\n").filter(l => l.trim().length > 0)
                    root.statusMsg = lines.length > 0
                        ? lines[lines.length - 1].trim()
                        : "Errore nel download"
                }
            }
        }
    }

    // ── UI ────────────────────────────────────────────────────────────
    Item {
        width: root.maxW
        height: root.maxH

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // header: titolo + chiudi
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "Scarica brano"
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 6
                    color: closeMa.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.textDim
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelRequested()
                    }
                }
            }

            // barra per incollare il link
            TextField {
                id: urlField
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                placeholderText: "Incolla il link YouTube…"
                color: Theme.text
                font.pixelSize: 13
                onAccepted: root.download()
                background: Rectangle {
                    color: "#2a2338"
                    radius: Theme.btnR
                }
            }

            // status (scaricando / ok / errore)
            Text {
                Layout.fillWidth: true
                text: root.statusMsg
                color: root.status === 3 ? "#e06c75"
                       : (root.status === 2 ? Theme.accent : Theme.textDim)
                font.pixelSize: 12
                elide: Text.ElideMiddle
                visible: root.statusMsg.length > 0
            }

            Item { Layout.fillHeight: true }   // spacer

            // tasto download
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: Theme.btnR
                color: dlMa.containsMouse ? Theme.activeHi : Theme.active
                Behavior on color { ColorAnimation { duration: Theme.hoverMs } }
                Text {
                    anchors.centerIn: parent
                    text: root.status === 1 ? "Scaricando…" : "Scarica"
                    color: Theme.bgSolid
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: dlMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.download()
                }
            }
        }
    }
}