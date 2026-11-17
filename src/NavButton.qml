import QtQuick
import QtQuick.Layouts

Rectangle {
    id: button

    property string label
    property string hint
    property string badge: ""
    property bool current: false
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 38
    radius: theme.radius
    color: current ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
                   : area.containsMouse ? theme.raised : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: button.label
            color: button.current ? theme.foreground : theme.subtle
            font.pixelSize: 15
            font.weight: button.current ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        Rectangle {
            visible: button.badge !== ""
            implicitWidth: Math.max(20, badgeText.implicitWidth + 10)
            implicitHeight: 20
            radius: 10
            color: theme.accent
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: button.badge
                color: theme.accentForeground
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
        Text {
            text: button.hint
            color: theme.subtle
            opacity: 0.55
            font.family: theme.mono
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
