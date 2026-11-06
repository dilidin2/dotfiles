import Quickshell
import Quickshell.Widgets
import QtQuick
import "."

// ─────────────────────────────────────────────────────────────────────
// Contenuto della barra sinistra (40px).
// Blocco alto FISSO 525px: workspace + separatore + finestre (scroll).
// Poi il bottone del dock. In fondo la waveform della musica.
// L'altezza fissa del blocco mantiene il bottone dock sempre centrato.
// ─────────────────────────────────────────────────────────────────────
Item {
    id: root
    property var niri
    property var dock
    property var screen

    // Finestre SOLO dello workspace attivo di QUESTO monitor (reattivo,
    // stile: w.workspace_id deve matchare lo workspace attivo).
    readonly property var activeWinList: {
        if (!root.niri || !root.screen) return []
        var screen = root.screen.name
        var activeWsId = -1
        var wss = root.niri.workspaces
        for (var i = 0; i < wss.length; i++) {
            if (wss[i].output === screen && wss[i].is_active) { activeWsId = wss[i].id; break }
        }
        if (activeWsId === -1) return []
        return root.niri.windows.filter(function(w) { return w.workspace_id === activeWsId })
    }

    readonly property int topBlockH: 525
    readonly property int dockBtnH: 36
    readonly property int waveH: Theme.waveBars * (Theme.waveBarH + Theme.waveBarGap)
                                + Theme.waveBottomPad

    Component.onCompleted: console.log("bar: screen=" + (root.screen ? root.screen.name : "null")
        + " niri=" + (root.niri ? "yes" : "no")
        + " ws=" + (root.niri ? root.niri.workspaces.length : -1))

    Timer {
        interval: 1200
        running: true
        onTriggered: console.log("bar(1.2s): screen=" + (root.screen ? root.screen.name : "null")
            + " ws=" + (root.niri ? root.niri.workspaces.length : -1)
            + " filtered=" + (root.niri && root.screen
                ? root.niri.workspaces.filter(ws => ws.output === root.screen.name).length : -2)
            + " wins=" + (root.niri && root.screen
                ? root.niri.workspaceWindows(root.niri.activeWorkspace(root.screen.name)).length : -2))
    }

    // ── Blocco alto ──────────────────────────────────────────────────
    Item {
        id: topBlock
        x: 0
        y: 0
        width: root.width
        height: root.topBlockH

        Column {
            id: topCol
            width: parent.width
            spacing: 4

            // Workspace di QUESTO monitor
            Column {
                id: wsCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.niri && root.niri.workspaces
                           ? root.niri.workspaces.filter(ws => ws.output === root.screen.name)
                                                      .sort((a, b) => a.idx - b.idx)
                           : []

                    delegate: Rectangle {
                        id: wsBtn

                        width: 30
                        height: 24
                        radius: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: modelData.is_active
                               ? Theme.active
                               : (wsMa.containsMouse ? Theme.hover : "transparent")

                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: String(modelData.idx)
                            color: modelData.is_active ? Theme.accent : Theme.text
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.niri.focusWorkspace(modelData.output, modelData.idx)
                        }
                    }
                }
            }

            // Separatore
            Rectangle {
                width: parent.width - 6
                height: 1
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.hover
            }

            // Finestre dello workspace attivo (scroll senza scrollbar)
            Flickable {
                id: winFlick
                width: parent.width
                height: Math.max(48, root.topBlockH - wsCol.height - 9)
                contentWidth: width
                contentHeight: winCol.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: winCol
                    width: winFlick.width
                    spacing: 2

                    Repeater {
                        model: root.activeWinList

                        delegate: Rectangle {
                            id: winBtn

                            width: 30
                            height: 28
                            radius: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.niri.isActiveWindow(root.screen.name, modelData)
                                   ? Theme.activeHi
                                   : (winMa.containsMouse ? Theme.hover : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: Theme.hoverMs }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 18
                                source: Quickshell.iconPath(
                                    modelData.app_id || "application-x-generic",
                                    "application-x-generic")
                            }

                            MouseArea {
                                id: winMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.niri.focusWindow(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Bottone dock (centrato: 525 + 36/2 ≈ 543) ─────────────────
    Item {
        id: dockButton
        x: 0
        y: root.topBlockH + 4
        width: root.width
        height: root.dockBtnH

        Rectangle {
            anchors.centerIn: parent
            width: 34
            height: 30
            radius: 6
            color: dockMa.containsMouse ? Theme.active : "transparent"

            Behavior on color {
                ColorAnimation { duration: Theme.hoverMs }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: Theme.icon("grid.svg")
            }

            MouseArea {
                id: dockMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.dock) root.dock.toggle()
            }
        }
    }

    // ── Waveform musica (in fondo, 120px dal bordo) ─────────────────
    Waveform {
        x: 0
        y: root.height - 120 - root.waveH
        width: Theme.waveWidth
        height: root.waveH
        onClicked: if (root.dock) root.dock.musicRequested()
    }
}
