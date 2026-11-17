import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One block of a lesson: paragraph, list, code, table or callout.
Loader {
    id: blockLoader

    property var block: ({})

    sourceComponent: {
        switch (block.tipo) {
        case "lista": return listComponent
        case "codigo": return codeComponent
        case "tabela": return tableComponent
        case "aviso": return calloutComponent
        default: return paragraphComponent
        }
    }

    Component {
        id: paragraphComponent
        RichLabel { raw: blockLoader.block.texto || "" }
    }

    Component {
        id: listComponent
        Column {
            spacing: 8
            Repeater {
                model: blockLoader.block.itens || []
                RowLayout {
                    required property var modelData
                    required property int index
                    width: parent.width
                    spacing: 10
                    Text {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 20
                        horizontalAlignment: Text.AlignRight
                        text: blockLoader.block.ordenada ? (index + 1) + "." : "•"
                        color: theme.accent
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        lineHeight: 1.3
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        raw: modelData
                    }
                }
            }
        }
    }

    Component {
        id: codeComponent
        Rectangle {
            id: codeBox
            color: Qt.darker(theme.surface, 1.25)
            radius: theme.radius
            border.color: theme.border
            implicitHeight: codeText.implicitHeight + 28

            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                anchors.rightMargin: 74
                contentWidth: codeText.implicitWidth
                contentHeight: codeText.implicitHeight
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                Text {
                    id: codeText
                    text: backend.codeHtml(blockLoader.block.texto || "", theme.subtle.toString())
                    textFormat: Text.StyledText
                    color: theme.foreground
                    font.family: theme.mono
                    font.pixelSize: 13
                    lineHeight: 1.35
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                implicitWidth: copyLabel.implicitWidth + 16
                implicitHeight: copyLabel.implicitHeight + 8
                radius: Math.min(4, theme.radius)
                color: copyArea.containsMouse ? theme.raised : "transparent"
                border.color: theme.border
                Text {
                    id: copyLabel
                    anchors.centerIn: parent
                    text: copied.running ? "Copiado" : "Copiar"
                    color: copied.running ? theme.ok : theme.subtle
                    font.pixelSize: 11
                }
                MouseArea {
                    id: copyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { backend.copy(blockLoader.block.texto); copied.restart() }
                }
                Timer { id: copied; interval: 1500 }
            }
        }
    }

    Component {
        id: tableComponent
        Rectangle {
            id: tableBox
            readonly property var columns: blockLoader.block.colunas || []
            readonly property var cells: {
                var out = []
                for (var c = 0; c < columns.length; c++)
                    out.push({ text: columns[c], header: true })
                var rows = blockLoader.block.linhas || []
                for (var r = 0; r < rows.length; r++)
                    for (var k = 0; k < rows[r].length; k++)
                        out.push({ text: rows[r][k], header: false })
                return out
            }
            color: theme.surface
            radius: theme.radius
            border.color: theme.border
            clip: true
            implicitHeight: grid.implicitHeight + 2

            GridLayout {
                id: grid
                x: 1; y: 1
                width: parent.width - 2
                columns: Math.max(1, tableBox.columns.length)
                rowSpacing: 0
                columnSpacing: 0

                Repeater {
                    model: tableBox.cells
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool lastRow: index >= tableBox.cells.length - tableBox.columns.length
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 100
                        implicitHeight: cellText.contentHeight + 18
                        color: modelData.header ? theme.raised : "transparent"
                        RichLabel {
                            id: cellText
                            x: 12; y: 9
                            width: parent.width - 24
                            raw: parent.modelData.text
                            font.pixelSize: 14
                            font.weight: parent.modelData.header ? Font.DemiBold : Font.Normal
                            color: parent.modelData.header ? theme.subtle : theme.foreground
                        }
                        Rectangle {
                            visible: !parent.lastRow
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: theme.border
                        }
                    }
                }
            }
        }
    }

    Component {
        id: calloutComponent
        Rectangle {
            id: callout
            readonly property string style: blockLoader.block.estilo || "dica"
            readonly property color tone: style === "real" ? theme.warn
                                        : style === "teste" ? theme.info
                                        : style === "dica" ? theme.ok
                                        : theme.accent
            readonly property string fallbackTitle: style === "real" ? "Caso real"
                                                  : style === "teste" ? "No teste"
                                                  : style === "dica" ? "Para lembrar"
                                                  : "Em uma frase"
            color: Qt.rgba(tone.r, tone.g, tone.b, 0.11)
            radius: theme.radius
            border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.35)
            implicitHeight: calloutColumn.implicitHeight + 28

            ColumnLayout {
                id: calloutColumn
                x: 16; y: 14
                width: parent.width - 32
                spacing: 6
                Text {
                    text: (blockLoader.block.titulo || callout.fallbackTitle).toUpperCase()
                    color: callout.tone
                    font.family: theme.mono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                RichLabel {
                    Layout.fillWidth: true
                    raw: blockLoader.block.texto || ""
                    font.pixelSize: callout.style === "resumo" ? 16 : 15
                    font.weight: callout.style === "resumo" ? Font.Medium : Font.Normal
                }
            }
        }
    }
}
