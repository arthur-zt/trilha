import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Flickable {
    id: root

    signal openLesson(string id)
    signal openChapter(string id)
    signal goTo(int view)

    readonly property int rev: backend.revision
    readonly property string continueId: rev, backend.lastLesson !== "" ? backend.lastLesson
                                                                       : backend.firstLessonOf("")
    readonly property var continueLesson: backend.lesson(continueId)

    contentHeight: column.implicitHeight + 80
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    ColumnLayout {
        id: column
        width: Math.min(root.width - 80, 1000)
        x: (root.width - width) / 2
        y: 40
        spacing: 22

        ColumnLayout {
            spacing: 6
            Text {
                text: "Trilha Infra & DevOps"
                color: theme.foreground
                font.pixelSize: 32
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: "Do “o que fazer” para o “por que acontece”. Leia uma lição, revise os termos e teste o que ficou."
                color: theme.subtle
                font.pixelSize: 16
                wrapMode: Text.Wrap
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 1000 ? 4 : 2
            columnSpacing: 14
            rowSpacing: 14

            StatCard {
                title: "Trilha"
                value: (root.rev, backend.itemsDone()) + " / " + backend.itemsTotal()
                detail: "itens concluídos"
                progress: (root.rev, backend.itemsDone() / Math.max(1, backend.itemsTotal()))
                onClicked: root.goTo(1)
            }
            StatCard {
                title: "Apostila"
                value: (root.rev, backend.readCount()) + " / " + backend.lessonsTotal()
                detail: "lições lidas"
                progress: (root.rev, backend.readCount() / Math.max(1, backend.lessonsTotal()))
                onClicked: root.goTo(2)
            }
            StatCard {
                title: "Flashcards"
                value: String((root.rev, backend.dueCount()))
                detail: "cartões para revisar hoje"
                onClicked: root.goTo(4)
            }
            StatCard {
                title: "Quiz"
                readonly property var stats: {
                    root.rev
                    var done = 0, right = 0, total = 0
                    var chapters = backend.chapters
                    for (var i = 0; i < chapters.length; i++) {
                        var s = backend.quizStats(chapters[i].id)
                        if (s.total) { done++; right += s.melhor; total += s.total }
                    }
                    return { done: done, pct: total ? Math.round(right / total * 100) : 0, chapters: chapters.length }
                }
                value: stats.done ? stats.pct + "%" : "—"
                detail: stats.done ? "acerto médio em " + stats.done + " de " + stats.chapters + " capítulos"
                                   : "nenhum quiz feito ainda"
                onClicked: root.goTo(5)
            }
        }

        Card {
            Layout.fillWidth: true
            clickable: true
            onClicked: root.openLesson(root.continueId)
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: (root.rev, backend.lastLesson !== "") ? "CONTINUE DE ONDE PAROU" : "COMECE POR AQUI"
                        color: theme.accent
                        font.family: theme.mono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.continueLesson.titulo || ""
                        color: theme.foreground
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }
                    Text {
                        text: "Capítulo " + root.continueLesson.capituloNumero + " · " + root.continueLesson.capituloTitulo
                              + " · lição " + root.continueLesson.posicao + " de " + root.continueLesson.totalCapitulo
                        color: theme.subtle
                        font.pixelSize: 13
                    }
                }
                AppButton {
                    text: "Abrir lição"
                    highlighted: true
                    onClicked: root.openLesson(root.continueId)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Card {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 3
                Text {
                    text: "Próximos itens da trilha"
                    color: theme.foreground
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: (root.rev, backend.nextItems(5))
                    ItemRow {
                        required property var modelData
                        Layout.fillWidth: true
                        item: modelData
                        phaseLabel: modelData.fase
                    }
                }
                Text {
                    visible: (root.rev, backend.itemsDone() === backend.itemsTotal())
                    text: "Trilha completa. Hora de definir a próxima."
                    color: theme.ok
                    font.pixelSize: 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 2
                spacing: 14

                Card {
                    Layout.fillWidth: true
                    Text {
                        text: "PERFIL"
                        color: theme.subtle
                        font.family: theme.mono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        raw: backend.diagnosis
                        font.pixelSize: 14
                    }
                }
                Repeater {
                    model: backend.extras
                    Card {
                        required property var modelData
                        Layout.fillWidth: true
                        Text {
                            text: modelData.titulo
                            color: theme.foreground
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                        RichLabel {
                            Layout.fillWidth: true
                            raw: modelData.texto
                            color: theme.subtle
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
