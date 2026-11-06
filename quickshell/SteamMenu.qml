import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Menu Steam: flyout a DESTRA del dock, allineato all'icona Steam.
// Stessa logica di Ignis (dock.py → SteamMenuWindow):
//   • giochi recenti (top 5, solo dati locali) → steam://run/<appid>
//   • separatori
//   • Libreria / Amici / Store / Impostazioni / Esci (URL ufficiali)
// Ogni voce apre l'URL con xdg-open e chiude il menu.
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    maxW: 200
    // Altezza dinamica: si adatta al numero di voci (niente vuoto in fondo)
    readonly property int menuH: {
        var n = root.recent.length
        var buttons = n + 5                 // 4 fissi + 1 esci
        var seps = (n > 0 ? 1 : 0) + 1
        var items = buttons + seps
        return buttons * 32 + seps * 1 + (items - 1) * 5 + 20
    }
    maxH: root.menuH
    growX: "right"
    growY: "none"
    attach: "left"
    convexBL: true                // basso-sx arrotondato normale (non concavo)
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel

    panelNamespace: "steam_menu"
    anchorLeft: true
    anchorTop: true
    // A destra del dock (x=280), allineato alla riga tray (y≈440).
    marginLeft: 280
    marginTop: 440

    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.OnDemand

    // ── voci ─────────────────────────────────────────────────────────
    property var recent: []

    readonly property var entries: {
        var list = []
        for (var i = 0; i < root.recent.length; i++)
            list.push({ label: root.recent[i].name,
                        url: "steam://run/" + root.recent[i].appid })
        if (root.recent.length > 0) list.push({ sep: true })
        list.push({ label: "Libreria",     url: "steam://open/games" })
        list.push({ label: "Amici",        url: "steam://open/friends" })
        list.push({ label: "Store",        url: "steam://store" })
        list.push({ label: "Impostazioni", url: "steam://settings" })
        list.push({ sep: true })
        list.push({ label: "Esci",         url: "steam://exit" })
        return list
    }

    // all'apertura ricarica i recenti (possono essere cambiati)
    onOpenChanged: {
        if (root.open)
            scanProc.exec(["/usr/bin/python3",
                           Quickshell.shellPath("scripts/steam_scan.py"),
                           "recent", "5"])
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.recent = JSON.parse(scanProc.stdout.data) }
                catch (e) { root.recent = [] }
            }
        }
    }

    Process { id: xdgProc }

    function openUrl(url) {
        xdgProc.exec(["xdg-open", url])
        root.closePanel()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.closePanel()
    }

    // ── contenuto (top-aligned, spazio vuoto in basso se pochi giochi) ─
    Item {
        width: root.maxW
        height: root.maxH

        ColumnLayout {
            x: 10
            y: 10
            width: root.maxW - 20
            spacing: 5

            Repeater {
                model: root.entries

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.sep ? 1 : 32
                    radius: modelData.sep ? 0 : Theme.btnR
                    color: modelData.sep
                           ? Theme.active
                           : (stMa.containsMouse ? Theme.hover : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs }
                    }

                    Text {
                        visible: !modelData.sep
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label || ""
                        color: Theme.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: stMa
                        anchors.fill: parent
                        visible: !modelData.sep
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openUrl(modelData.url)
                    }
                }
            }
        }
    }
}
