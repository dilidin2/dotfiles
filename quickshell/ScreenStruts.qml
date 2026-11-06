import QtQuick
import "."

// I 4 bordi riservati (come `edge()` in config.py di Ignis).
// Vengono creati per OGNI monitor: la cornice c'è su entrambi.
Item {
    id: root
    required property var modelData
    readonly property var screen: root.modelData

    Strut {
        screen: root.modelData
        anchors { left: true; top: true; bottom: true }
        implicitWidth: Theme.leftW
    }
    Strut {
        screen: root.modelData
        anchors { right: true; top: true; bottom: true }
        implicitWidth: Theme.rightW
    }
    Strut {
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.topH
    }
    Strut {
        screen: root.modelData
        anchors { bottom: true; left: true; right: true }
        implicitHeight: Theme.bottomH
    }
}
