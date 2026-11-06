import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "."

// ─────────────────────────────────────────────────────────────────────
// Cornice: UNA superficie per monitor.
//  • forma = rettangolo esterno − rettangolo interno arrotondato (R=20)
//  • maschera input = stessa forma (il centro resta cliccabile)
//  • blur = ext-background-effect sulla stessa forma
//  • barra sinistra con i widget solo su DP-3
// ─────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root
    required property var modelData

    property var niri
    property var dock

    readonly property bool withBar: modelData.name === "DP-3"

    screen: root.modelData
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    // Namespace attesi dalla config niri (layer-rule per il blur):
    // ^ignis_frame_(top|bottom|left|right)_
    WlrLayershell.namespace: "ignis_frame_" + root.modelData.name + "_"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // (blur rimosso: colore solido, il blur divideva il tono tra barra
    //  e pannelli) — la Region resta solo come maschera input
    mask: frameRegion

    // ── Forma della cornice (maschera) ───────────────────────────────
    Region {
        id: frameRegion
        width: root.width
        height: root.height

        Region {
            x: Theme.leftW
            y: Theme.topH
            width: root.width - Theme.leftW - Theme.rightW
            height: root.height - Theme.topH - Theme.bottomH
            radius: Theme.cornerR
            intersection: Intersection.Subtract
        }
    }

    // ── Disegno: esterno pieno, interno sottratto (even-odd) ─────────
    Shape {
        anchors.fill: parent
        ShapePath {
            fillColor: Theme.bgFrame
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill

            PathRectangle {
                x: 0; y: 0
                width: root.width
                height: root.height
            }
            PathRectangle {
                x: Theme.leftW
                y: Theme.topH
                width: root.width - Theme.leftW - Theme.rightW
                height: root.height - Theme.topH - Theme.bottomH
                radius: Theme.cornerR
            }
        }
    }

    // ── Widget della barra sinistra ──────────────────────────────────
    LeftBar {
        visible: root.withBar
        x: 0
        y: Theme.topH
        width: Theme.leftW
        height: root.height - Theme.topH - Theme.bottomH
        screen: root.modelData
        niri: root.niri
        dock: root.dock
    }
}
