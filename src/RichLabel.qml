import QtQuick

// Text in the content's markup (**bold**, *italic*, `code`).
Text {
    property string raw: ""
    property color codeColor: Qt.tint(theme.foreground, Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45))

    text: backend.rich(raw, codeColor.toString())
    textFormat: Text.RichText
    wrapMode: Text.Wrap
    color: theme.foreground
    linkColor: theme.accent
    font.pixelSize: 15
    lineHeight: 1.3
}
