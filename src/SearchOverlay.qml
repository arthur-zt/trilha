import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Ctrl+K: find any lesson, term or trilha item.
Popup {
    id: popup

    signal picked(string kind, string target)

    function choose(index) {
        var hit = results.model[index]
        if (!hit)
            return
        close()
        picked(hit.tipo, hit.alvo)
    }

    parent: Overlay.overlay
    modal: true
    focus: true
    x: (parent.width - width) / 2
    y: Math.max(40, parent.height * 0.12)
    width: Math.min(parent.width - 80, 680)
    padding: 0
    onOpened: { field.text = ""; field.forceActiveFocus() }

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
    background: Rectangle {
        color: theme.surface
        radius: theme.radius
        border.color: theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0

        TextField {
            id: field
            Layout.fillWidth: true
            Layout.margins: 14
            placeholderText: "Buscar lição, termo ou item da trilha"
            Keys.onDownPressed: results.incrementCurrentIndex()
            Keys.onUpPressed: results.decrementCurrentIndex()
            Keys.onReturnPressed: popup.choose(results.currentIndex)
            Keys.onEnterPressed: popup.choose(results.currentIndex)
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.border }

        ListView {
            id: results
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 420)
            model: backend.search(field.text)
            clip: true
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            onModelChanged: currentIndex = 0

            delegate: Rectangle {
                id: hit
                required property var modelData
                required property int index
                readonly property color tone: modelData.tipo === "termo" ? theme.info
                                            : modelData.tipo === "item" ? theme.warn : theme.accent
                width: ListView.view.width
                implicitHeight: hitColumn.implicitHeight + 18
                color: ListView.isCurrentItem ? theme.raised : "transparent"

                ColumnLayout {
                    id: hitColumn
                    x: 16; y: 9
                    width: parent.width - 32
                    spacing: 3
                    RowLayout {
                        spacing: 8
                        Chip {
                            text: hit.modelData.tipo === "termo" ? "termo" : hit.modelData.tipo === "item" ? "trilha" : "lição"
                            tone: hit.tone
                        }
                        Text {
                            Layout.fillWidth: true
                            text: hit.modelData.titulo
                            color: theme.foreground
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: hit.modelData.contexto
                        color: theme.subtle
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: results.currentIndex = hit.index
                    onClicked: popup.choose(hit.index)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.margins: 16
            visible: results.count === 0
            text: field.text.trim().length < 2 ? "Digite ao menos 2 letras. Acentos não importam: “replicacao” acha “replicação”."
                                               : "Nada encontrado para “" + field.text + "”."
            color: theme.subtle
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            Layout.margins: 10
            Layout.leftMargin: 16
            text: "↑ ↓ escolher · Enter abrir · Esc fechar"
            color: theme.subtle
            opacity: 0.7
            font.family: theme.mono
            font.pixelSize: 11
        }
    }
}
