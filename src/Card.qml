import QtQuick
import QtQuick.Layouts

// A bordered panel whose height follows its content. Set `clickable` to make
// the whole panel a button.
Rectangle {
    id: card

    default property alias content: inner.data
    property int padding: 20
    property alias spacing: inner.spacing
    property bool clickable: false
    signal clicked()

    color: theme.surface
    radius: theme.radius
    border.width: 1
    border.color: clickable && hover.containsMouse ? theme.accent : theme.border
    implicitHeight: inner.implicitHeight + padding * 2

    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: card.clickable
        hoverEnabled: card.clickable
        cursorShape: card.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.clicked()
    }

    ColumnLayout {
        id: inner
        x: card.padding
        y: card.padding
        width: card.width - card.padding * 2
        spacing: 10
    }
}
