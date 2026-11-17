import QtQuick

// The app's button: filled in the accent when `highlighted`, plain text when
// `flat`, a quiet panel otherwise. `tone` recolors it (right / wrong).
Rectangle {
    id: button

    property string text
    property bool highlighted: false
    property bool flat: false
    property color tone: highlighted ? theme.accent : theme.foreground
    property bool toned: false
    signal clicked()

    readonly property bool filled: highlighted || toned
    readonly property color textColor: !enabled ? theme.subtle
                                     : highlighted ? theme.accentForeground
                                     : toned ? theme.foreground
                                     : flat ? Qt.tint(theme.foreground, Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.5))
                                     : theme.foreground

    implicitWidth: label.implicitWidth + (flat ? 20 : 32)
    implicitHeight: 38
    radius: Math.min(6, theme.radius)
    opacity: enabled ? 1 : 0.5
    color: {
        if (highlighted) return area.pressed ? Qt.darker(theme.accent, 1.2) : area.containsMouse ? Qt.lighter(theme.accent, 1.12) : theme.accent
        if (toned) return Qt.rgba(tone.r, tone.g, tone.b, area.containsMouse ? 0.38 : 0.26)
        if (flat) return area.containsMouse ? theme.raised : "transparent"
        return area.containsMouse ? Qt.lighter(theme.raised, 1.15) : theme.raised
    }
    border.width: filled || flat ? 0 : 1
    border.color: theme.border

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.textColor
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
