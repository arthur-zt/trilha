import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root

    signal openLesson(string id)

    readonly property var categories: ["Todas", "Redes", "Linux", "Git e containers", "Confiabilidade",
                                       "IaC", "Cloud e segurança", "Kubernetes"]
    property string category: "Todas"
    property string highlighted: ""
    readonly property var terms: {
        var query = backend.normalizeText(filter.text.trim())
        var all = backend.glossary, out = []
        for (var i = 0; i < all.length; i++) {
            var term = all[i]
            if (category !== "Todas" && term.categoria !== category) continue
            if (query && term.busca.indexOf(query) < 0) continue
            out.push(term)
        }
        return out
    }

    function focusTerm(name) {
        filter.text = ""
        category = "Todas"
        highlighted = name
        Qt.callLater(function() {
            for (var i = 0; i < terms.length; i++)
                if (terms[i].termo === name) { list.positionViewAtIndex(i, ListView.Beginning); return }
        })
    }
    function focusFilter() { filter.forceActiveFocus() }

    ColumnLayout {
        width: Math.min(root.width - 80, 900)
        x: (root.width - width) / 2
        y: 40
        height: root.height - 40
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Glossário"
                color: theme.foreground
                font.pixelSize: 30
                font.weight: Font.Bold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.terms.length + " de " + backend.glossary.length + " termos"
                color: theme.subtle
                font.pixelSize: 13
            }
        }

        TextField {
            id: filter
            Layout.fillWidth: true
            placeholderText: "Filtrar por termo, sigla ou palavra da definição"
            Keys.onEscapePressed: { text = ""; root.forceActiveFocus() }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.categories
                Rectangle {
                    required property string modelData
                    readonly property bool on: root.category === modelData
                    implicitWidth: catLabel.implicitWidth + 20
                    implicitHeight: catLabel.implicitHeight + 10
                    radius: Math.min(4, theme.radius)
                    color: on ? theme.accent : catArea.containsMouse ? theme.raised : theme.surface
                    border.color: on ? theme.accent : theme.border
                    Text {
                        id: catLabel
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.on ? theme.accentForeground : theme.subtle
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: catArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.category = parent.modelData
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.terms
            spacing: 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            bottomMargin: 30

            delegate: ColumnLayout {
                id: entry
                required property var modelData
                required property int index
                readonly property bool firstOfLetter: index === 0 || root.terms[index - 1].letra !== modelData.letra
                width: ListView.view.width - 14
                spacing: 8

                Text {
                    visible: entry.firstOfLetter
                    Layout.topMargin: entry.index === 0 ? 0 : 12
                    text: entry.modelData.letra
                    color: theme.accent
                    font.family: theme.mono
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                Card {
                    Layout.fillWidth: true
                    border.color: root.highlighted === entry.modelData.termo ? theme.accent : theme.border
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: entry.modelData.termo
                            color: theme.foreground
                            font.pixelSize: 19
                            font.weight: Font.Bold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.nome || ""
                            color: theme.subtle
                            font.pixelSize: 14
                            font.italic: true
                            elide: Text.ElideRight
                        }
                        Chip { text: entry.modelData.categoria }
                        Chip {
                            readonly property int box: (backend.revision, backend.cardBox(entry.modelData.termo))
                            visible: box > 0
                            text: "caixa " + box
                            tone: box >= 4 ? theme.ok : theme.info
                        }
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        raw: entry.modelData.definicao
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        visible: !!entry.modelData.exemplo
                        raw: entry.modelData.exemplo ? "**Na prática:** " + entry.modelData.exemplo : ""
                        color: theme.subtle
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Ver na apostila →"
                        color: theme.accent
                        font.pixelSize: 13
                        font.underline: lessonHover.hovered
                        HoverHandler { id: lessonHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.openLesson(entry.modelData.licao) }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.terms.length === 0
                text: "Nenhum termo encontrado."
                color: theme.subtle
                font.pixelSize: 15
            }
        }
    }
}
