import QtQuick

// A small uppercase label tinted with `tone`.
Rectangle {
    id: chip

    property string text
    property color tone: theme.subtle

    radius: Math.min(4, theme.radius)
    color: Qt.rgba(tone.r, tone.g, tone.b, 0.16)
    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 5

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text.toUpperCase()
        color: chip.tone
        font.family: theme.mono
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }
}
