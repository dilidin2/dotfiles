import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// ─────────────────────────────────────────────────────────────────────
// Launcher: pannello 480×560 che esce dall'angolo in alto a destra.
// Raccordi concavi "allungati" in alto-sx, alto-dx (angolo) e basso-dx
// (stesso stile del dock agganciato alla barra).
// Elenco app da DesktopEntries.applications, ordinato per uso poi nome.
// ─────────────────────────────────────────────────────────────────────
MorphPanel {
    id: root

    maxW: Theme.launcherW
    maxH: Theme.launcherH
    growX: "left"
    growY: "down"
    attach: "trElong"
    filletR: Theme.filletR
    outerR: Theme.panelR
    bgColor: Theme.bgPanel
    panelNamespace: "launcher"
    anchorLeft: false
    anchorRight: true
    anchorTop: true
    marginRight: Theme.rightW
    marginTop: Theme.topH
    wantsKeyboard: true
    keyboardFocusWhenOpen: WlrKeyboardFocus.Exclusive

    // ── dati app ────────────────────────────────────────────────────
    // .values è reattivo: si aggiorna quando il modello si popola.
    property var allApps: DesktopEntries.applications.values
    property var filteredApps: []
    property var usage: ({})
    property int selectedIndex: 0
    property string query: ""

    onAllAppsChanged: root.applyFilter()

    // ── conteggio d'uso (app_usage.json) ────────────────────────────
    Process {
        id: usageProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.usage = JSON.parse(String(usageProc.stdout.data))
                } catch (e) {
                    root.usage = ({})
                }
                root.applyFilter()
            }
        }
    }
    Process {
        id: bumpProc
        stdout: StdioCollector {}
    }

    function loadUsage() {
        usageProc.exec(["cat", Quickshell.shellPath("app_usage.json")])
    }
    function applyFilter() {
        var q = root.query.trim().toLowerCase()
        var vals = DesktopEntries.applications.values
        var list = []
        for (var i = 0; i < vals.length; i++) {
            var e = vals[i]
            var nm = (e.name || "").toLowerCase()
            var cm = (e.comment || "").toLowerCase()
            var kw = (e.keywords || []).join(" ").toLowerCase()
            if (q && nm.indexOf(q) < 0 && cm.indexOf(q) < 0 && kw.indexOf(q) < 0)
                continue
            list.push(e)
        }
        list.sort(function (a, b) {
            var ua = root.usage[a.id] || 0
            var ub = root.usage[b.id] || 0
            if (ub !== ua) return ub - ua
            return (a.name || "").localeCompare(b.name || "")
        })
        root.filteredApps = list
        root.selectedIndex = 0
    }
    function moveSel(d) {
        var n = root.filteredApps.length
        if (n === 0) return
        root.selectedIndex = (root.selectedIndex + d + n) % n
    }
    function launchAt(i) {
        var e = root.filteredApps[i]
        if (!e) return
        e.execute()
        bumpProc.exec(["/usr/bin/python3",
                       Quickshell.shellPath("scripts/launcher_apps.py"),
                       "bump", e.id])
        root.closePanel()
    }

    // focus sulla ricerca appena aperto
    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    onOpenChanged: {
        if (open) {
            root.loadUsage()
            root.applyFilter()
            focusTimer.start()
        }
    }

    // ── tastiera ────────────────────────────────────────────────────
    Shortcut { sequence: "Escape"; onActivated: root.closePanel() }
    Shortcut { sequence: "Down";   onActivated: root.moveSel(1) }
    Shortcut { sequence: "Up";     onActivated: root.moveSel(-1) }
    Shortcut { sequence: "Return"; onActivated: root.launchAt(root.selectedIndex) }

    // ── contenuto (480×560, ritagliato dalla forma) ─────────────────
    Item {
        width: root.maxW
        height: root.maxH

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // ricerca
            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                placeholderText: "Cerca app…"
                text: root.query
                onTextChanged: { root.query = text; root.applyFilter() }
                background: Rectangle {
                    radius: 8
                    color: searchField.activeFocus ? "#2f2740" : Theme.hover
                }
                color: Theme.text
                placeholderTextColor: Theme.textDim
                font.pixelSize: 14
                leftPadding: 10
                rightPadding: 10
                topPadding: 6
                bottomPadding: 6
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.active
            }

            // lista app
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: appCol.height
                clip: true

                Column {
                    id: appCol
                    width: parent.width
                    spacing: 4

                    Text {
                        width: parent.width
                        visible: root.filteredApps.length === 0
                        text: "Nessuna app"
                        color: Theme.textDim
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        padding: 8
                    }

                    Repeater {
                        model: root.filteredApps

                        delegate: Rectangle {
                            id: arow
                            width: appCol.width
                            height: 44
                            radius: 8
                            color: root.selectedIndex === index
                                   ? Theme.active
                                   : (arowMa.containsMouse ? Theme.hover
                                                          : "transparent")
                            Behavior on color {
                                ColorAnimation { duration: Theme.hoverMs }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Image {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    source: Quickshell.iconPath(
                                                modelData.icon,
                                                "application-x-generic")
                                    fillMode: Image.PreserveAspectFit
                                }
                                Column {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.name
                                        color: Theme.text
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: modelData.comment
                                        color: Theme.textDim
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        width: parent.width
                                        visible: text.length > 0
                                    }
                                }
                            }

                            MouseArea {
                                id: arowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = index
                                    root.launchAt(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
