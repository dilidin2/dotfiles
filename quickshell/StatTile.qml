import Quickshell.Widgets
import QtQuick
import "."

// Tile statistica del dock: quadrato colorato, icona + valore.
Rectangle {
    id: root
    property string iconSource: ""
    property string value: "—"
    property color tileColor: Theme.active
    signal clicked()

    radius: Theme.tileR
    color: hover.hovered ? Qt.lighter(root.tileColor, 1.22) : root.tileColor

    Behavior on color {
        ColorAnimation { duration: Theme.hoverMs }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitSize: 22
            source: root.iconSource
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.value
            color: Theme.text
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
