import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Flickable {
    id: root

    signal openChapter(string id)

    function focusPhase(phaseId) {
        for (var i = 0; i < phases.count; i++) {
            var card = phases.itemAt(i)
            if (card && card.phaseId === phaseId) {
                contentY = Math.max(0, Math.min(card.y + column.y - 20, contentHeight - height))
                card.flash()
                return
            }
        }
    }

    contentHeight: column.implicitHeight + 80
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    ColumnLayout {
        id: column
        width: Math.min(root.width - 80, 900)
        x: (root.width - width) / 2
        y: 40
        spacing: 18

        ColumnLayout {
            spacing: 6
            Text {
                text: "Trilha de estudos"
                color: theme.foreground
                font.pixelSize: 30
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: "Seis fases, cerca de 4 a 5 horas por semana. Cada fase mistura leitura, laboratório numa VM descartável e uma tarefa na infra de verdade."
                color: theme.subtle
                font.pixelSize: 15
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.topMargin: 6
                spacing: 16
                Repeater {
                    model: [
                        { t: "estudo", d: "leitura ou curso", c: theme.subtle },
                        { t: "lab", d: "prática numa VM", c: theme.info },
                        { t: "ambiente", d: "na infra real", c: theme.warn }
                    ]
                    RowLayout {
                        required property var modelData
                        spacing: 6
                        Chip { text: modelData.t; tone: modelData.c }
                        Text { text: modelData.d; color: theme.subtle; font.pixelSize: 13 }
                    }
                }
            }
        }

        Repeater {
            id: phases
            model: backend.phases

            Card {
                id: phaseCard
                required property var modelData
                required property int index
                readonly property string phaseId: modelData.id
                readonly property int done: (backend.revision, backend.phaseDone(modelData.id))
                readonly property int total: modelData.itens.length

                function flash() { flashAnimation.restart() }

                Layout.fillWidth: true
                spacing: 12

                SequentialAnimation {
                    id: flashAnimation
                    ColorAnimation { target: phaseCard; property: "border.color"; to: theme.accent; duration: 150 }
                    PauseAnimation { duration: 900 }
                    ColorAnimation { target: phaseCard; property: "border.color"; to: theme.border; duration: 400 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: phaseNumber.implicitWidth + 16
                        implicitHeight: phaseNumber.implicitHeight + 8
                        radius: Math.min(4, theme.radius)
                        color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
                        Text {
                            id: phaseNumber
                            anchors.centerIn: parent
                            text: "Fase " + (phaseCard.index + 1)
                            color: Qt.lighter(theme.accent, 1.4)
                            font.family: theme.mono
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: phaseCard.modelData.titulo
                            color: theme.foreground
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: phaseCard.modelData.semanas
                            color: theme.subtle
                            font.family: theme.mono
                            font.pixelSize: 12
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            text: phaseCard.modelData.resumo
                            color: theme.subtle
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                        }
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 6
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: phaseCard.done + "/" + phaseCard.total
                            color: phaseCard.done === phaseCard.total ? theme.ok : theme.subtle
                            font.family: theme.mono
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        AppButton {
                            flat: true
                            text: "Ler capítulo →"
                            onClicked: root.openChapter(phaseCard.modelData.capitulo)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 3
                    radius: 2
                    color: theme.raised
                    Rectangle {
                        width: parent.width * phaseCard.done / Math.max(1, phaseCard.total)
                        height: parent.height
                        radius: 2
                        color: phaseCard.done === phaseCard.total ? theme.ok : theme.accent
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }

                Repeater {
                    model: phaseCard.modelData.itens
                    ItemRow {
                        required property var modelData
                        Layout.fillWidth: true
                        item: modelData
                    }
                }
            }
        }
    }
}
