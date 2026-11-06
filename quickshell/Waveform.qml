import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "."

// ─────────────────────────────────────────────────────────────────────
// Waveform della musica nella barra sinistra.
// 22 barre orizzontali, larghezza = livello audio (0..1).
// Livello dal monitor del sink di default (PipeWire), senza parec.
// ─────────────────────────────────────────────────────────────────────
Item {
    id: root
    signal clicked()

    readonly property int n: Theme.waveBars
    property var levels: new Array(Theme.waveBars).fill(0)
    property var targets: new Array(Theme.waveBars).fill(0)
    property int tickCount: 0

    PwNodePeakMonitor {
        id: peak
        node: Pipewire.defaultAudioSink
        enabled: true
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: root.tick()
    }

    function tick() {
        const cur = Math.min(1, Math.max(0, peak.peak * 2.5))
        root.tickCount += 1

        let t = root.targets.slice()
        if (root.tickCount % 4 === 0) {
            for (let i = 0; i < root.n; i++) {
                const weight = 1.0 - (i / root.n) * 0.7
                t[i] = cur * weight * (0.35 + 0.65 * Math.random())
            }
        }

        let l = root.levels.slice()
        for (let i = 0; i < root.n; i++)
            l[i] += (t[i] - l[i]) * 0.5

        root.targets = t
        root.levels = l
    }

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.waveBarGap

        Repeater {
            model: root.n

            delegate: Rectangle {
                id: bar
                readonly property int i: root.n - 1 - index
                readonly property real t: i / Math.max(1, root.n - 1)

                width: Math.max(2, root.levels[i] * (Theme.waveWidth - 10))
                height: Theme.waveBarH
                radius: height / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(0.62 + 0.18 * t,
                               0.48 + 0.14 * t,
                               0.82 + 0.16 * t,
                               0.95)
                opacity: waveMa.containsMouse ? 1.0 : 0.92

                Behavior on opacity {
                    NumberAnimation { duration: Theme.hoverMs }
                }
            }
        }
    }

    MouseArea {
        id: waveMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
