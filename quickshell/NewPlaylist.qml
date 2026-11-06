import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Flyout "Nuova playlist": spunta a DESTRA del pannello musica (stesso
// pattern del flyout Wi-Fi, crescita da sinistra a destra). Form con
// Nome + Mood; a "Crea" lancia music_scan.py create e emette created().
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    maxW: 260
    maxH: 200
    growX: "right"
    growY: "none"
    attach: "left"
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel

    panelNamespace: "new_pl_dialog"
    anchorLeft: true
    anchorTop: true
    // a destra del pannello musica (x=460), centrata verticalmente sul pannello
    marginLeft: 460
    marginTop: 745

    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── stato ────────────────────────────────────────────────────────
    property string song: ""   // canzone da aggiungere alla nuova playlist

    signal created(string name)
    signal cancelRequested()

    function openPl(s) {
        root.song = s || ""
        nameField.text = ""
        moodField.text = ""
        openPanel()
    }

    onOpenChanged: if (root.open) nameField.forceActiveFocus()

    Shortcut {
        sequence: "Escape"
        onActivated: root.cancelRequested()
    }

    // ── creazione ────────────────────────────────────────────────────
    function create() {
        const name = nameField.text.trim()
        if (!name) return
        // exec() setta il comando al momento del click e avvia (stoppa eventuali run precedenti)
        createProc.exec([
            "/usr/bin/python3",
            Quickshell.shellPath("scripts/music_scan.py"),
            "create", name, moodField.text.trim(), root.song
        ])
    }
    Process {
        id: createProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out.length > 0) root.created(out)
            }
        }
    }

    // ── form ─────────────────────────────────────────────────────────
    Item {
        width: root.maxW
        height: root.maxH

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                text: "Nuova playlist"
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                placeholderText: "Nome"
                color: Theme.text
                font.pixelSize: 13
                background: Rectangle {
                    color: "#2a2338"
                    radius: Theme.btnR
                }
            }

            TextField {
                id: moodField
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                placeholderText: "Mood (opzionale)"
                color: Theme.text
                font.pixelSize: 13
                onAccepted: root.create()
                background: Rectangle {
                    color: "#2a2338"
                    radius: Theme.btnR
                }
            }

            Item { Layout.fillHeight: true }   // spacer

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.btnR
                    color: annMa.containsMouse ? Theme.hover : Theme.bgSolid
                    Text {
                        anchors.centerIn: parent
                        text: "Annulla"
                        color: Theme.text
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: annMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancelRequested()
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.btnR
                    color: creaMa.containsMouse ? Theme.activeHi : Theme.active
                    Text {
                        anchors.centerIn: parent
                        text: "Crea"
                        color: Theme.bgSolid
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: creaMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.create()
                    }
                }
            }
        }
    }
}
