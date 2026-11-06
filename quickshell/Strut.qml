import Quickshell
import Quickshell.Wayland
import QtQuick

// Finestra invisibile che serve SOLO a riservare spazio a niri.
// 3 anchors + implicitWidth/Height + ExclusionMode.Auto (default)
// → niri riserva esattamente il bordo, senza disegnare nulla.
PanelWindow {
    color: "transparent"
    mask: Region {}
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs_strut"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
