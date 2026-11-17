import QtQuick
import QtQuick.Layouts

Card {
    id: stat

    property string title
    property string value
    property string detail
    property real progress: -1

    Layout.fillWidth: true
    Layout.preferredWidth: 100
    Layout.fillHeight: true
    clickable: true
    spacing: 6

    Text {
        text: stat.title.toUpperCase()
        color: theme.subtle
        font.family: theme.mono
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 1
    }
    Text {
        text: stat.value
        color: theme.foreground
        font.pixelSize: 30
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }
    Text {
        Layout.fillWidth: true
        text: stat.detail
        color: theme.subtle
        font.pixelSize: 13
        wrapMode: Text.Wrap
    }
    Rectangle {
        visible: stat.progress >= 0
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 4
        radius: 2
        color: theme.raised
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, stat.progress))
            height: parent.height
            radius: 2
            color: theme.accent
            Behavior on width { NumberAnimation { duration: 250 } }
        }
    }
}
