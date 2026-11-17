import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root

    signal openLesson(string id)

    property string chapterId: ""
    property string chapterTitle: ""
    property var questions: []
    property int position: 0
    property int choice: -1
    property int score: 0
    property var misses: []
    property string mode: "menu"   // menu | question | result
    readonly property var current: mode === "question" ? questions[position] : null

    function shuffle(list) {
        var copy = list.slice()
        for (var i = copy.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1))
            var t = copy[i]; copy[i] = copy[j]; copy[j] = t
        }
        return copy
    }
    function start(id, title) {
        var all = shuffle(backend.quiz(id))
        if (all.length === 0)
            return
        chapterId = id
        chapterTitle = title
        questions = id === "" ? all.slice(0, 15) : all
        position = 0
        choice = -1
        score = 0
        misses = []
        mode = "question"
    }
    function pick(index) {
        if (mode !== "question" || choice >= 0 || !current || index >= current.opcoes.length)
            return
        choice = index
        if (index === current.correta) {
            score++
        } else {
            var copy = misses.slice()
            copy.push(current)
            misses = copy
        }
    }
    function advance() {
        if (choice < 0)
            return
        if (position + 1 < questions.length) {
            position++
            choice = -1
            page.contentY = 0
        } else {
            backend.recordQuiz(chapterId, score, questions.length)
            mode = "result"
        }
    }
    function primary() {
        if (mode === "question") advance()
        else if (mode === "result") mode = "menu"
    }

    Shortcut { sequence: "1"; enabled: root.visible && root.mode === "question"; context: Qt.ApplicationShortcut; onActivated: root.pick(0) }
    Shortcut { sequence: "2"; enabled: root.visible && root.mode === "question"; context: Qt.ApplicationShortcut; onActivated: root.pick(1) }
    Shortcut { sequence: "3"; enabled: root.visible && root.mode === "question"; context: Qt.ApplicationShortcut; onActivated: root.pick(2) }
    Shortcut { sequence: "4"; enabled: root.visible && root.mode === "question"; context: Qt.ApplicationShortcut; onActivated: root.pick(3) }
    Shortcut { sequences: ["Return", "Enter"]; enabled: root.visible && root.mode === "question" && root.choice >= 0; context: Qt.ApplicationShortcut; onActivated: root.advance() }

    // Menu: one card per chapter, plus a mixed quiz.
    Flickable {
        anchors.fill: parent
        visible: root.mode === "menu"
        contentHeight: menuColumn.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: menuColumn
            width: Math.min(parent.width - 80, 900)
            x: (parent.width - width) / 2
            y: 40
            spacing: 16

            Text {
                text: "Quiz"
                color: theme.foreground
                font.pixelSize: 30
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: "Perguntas de cenário que cobram o mecanismo, não decoreba. Cada resposta vem com a explicação. Responda com 1 a 4 e avance com Enter."
                color: theme.subtle
                font.pixelSize: 15
                wrapMode: Text.Wrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 700 ? 3 : 2
                columnSpacing: 14
                rowSpacing: 14

                Repeater {
                    model: backend.chapters
                    Card {
                        required property var modelData
                        readonly property var stats: (backend.revision, backend.quizStats(modelData.id))
                        readonly property int count: backend.quiz(modelData.id).length
                        Layout.fillWidth: true
                        Layout.preferredWidth: 100
                        Layout.fillHeight: true
                        clickable: count > 0
                        onClicked: root.start(modelData.id, modelData.titulo)
                        spacing: 6

                        Text {
                            text: "CAPÍTULO " + modelData.numero
                            color: theme.subtle
                            font.family: theme.mono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.titulo
                            color: theme.foreground
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        Text {
                            text: count + " perguntas"
                            color: theme.subtle
                            font.pixelSize: 13
                        }
                        Text {
                            Layout.topMargin: 6
                            text: stats.total ? "Melhor: " + stats.melhor + "/" + stats.total + " · " + stats.tentativas
                                                + (stats.tentativas === 1 ? " tentativa" : " tentativas")
                                              : "Ainda não feito"
                            color: !stats.total ? theme.subtle
                                 : stats.melhor / stats.total >= 0.75 ? theme.ok : theme.warn
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Card {
                    readonly property var stats: (backend.revision, backend.quizStats(""))
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                    Layout.fillHeight: true
                    clickable: true
                    onClicked: root.start("", "Geral")
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.1)
                    spacing: 6
                    Text {
                        text: "MISTURADO"
                        color: Qt.lighter(theme.accent, 1.4)
                        font.family: theme.mono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                    Text {
                        text: "Quiz geral"
                        color: theme.foreground
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "15 perguntas sorteadas de todos os capítulos"
                        color: theme.subtle
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.topMargin: 6
                        text: parent.parent.stats.total ? "Melhor: " + parent.parent.stats.melhor + "/" + parent.parent.stats.total
                                                       : "Ainda não feito"
                        color: theme.subtle
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // Question.
    Flickable {
        id: page
        anchors.fill: parent
        visible: root.mode === "question"
        contentHeight: questionColumn.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: questionColumn
            width: Math.min(parent.width - 80, 780)
            x: (parent.width - width) / 2
            y: 40
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: (root.chapterTitle + " · pergunta " + (root.position + 1) + " de " + root.questions.length).toUpperCase()
                    color: theme.subtle
                    font.family: theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                Text { text: "✓ " + root.score; color: theme.ok; font.pixelSize: 14 }
                AppButton { flat: true; text: "Sair"; onClicked: root.mode = "menu" }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 3
                radius: 2
                color: theme.raised
                Rectangle {
                    width: parent.width * (root.position + (root.choice >= 0 ? 1 : 0)) / Math.max(1, root.questions.length)
                    height: parent.height
                    radius: 2
                    color: theme.accent
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }

            RichLabel {
                Layout.fillWidth: true
                Layout.topMargin: 8
                raw: root.current ? root.current.pergunta : ""
                font.pixelSize: 21
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.current ? root.current.opcoes : []
                Rectangle {
                    id: option
                    required property var modelData
                    required property int index
                    readonly property bool answered: root.choice >= 0
                    readonly property bool correct: root.current && index === root.current.correta
                    readonly property bool chosen: index === root.choice
                    readonly property color tone: answered && correct ? theme.ok : answered && chosen ? theme.danger : theme.border

                    Layout.fillWidth: true
                    implicitHeight: optionRow.implicitHeight + 26
                    radius: theme.radius
                    color: answered && (correct || chosen) ? Qt.rgba(tone.r, tone.g, tone.b, 0.13)
                         : optionArea.containsMouse && !answered ? theme.raised : theme.surface
                    border.width: answered && (correct || chosen) ? 2 : 1
                    border.color: tone
                    opacity: answered && !correct && !chosen ? 0.55 : 1

                    RowLayout {
                        id: optionRow
                        x: 14
                        width: parent.width - 28
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Math.min(4, theme.radius)
                            color: option.answered && (option.correct || option.chosen) ? option.tone : theme.raised
                            Text {
                                anchors.centerIn: parent
                                text: option.answered && option.correct ? "✓"
                                    : option.answered && option.chosen ? "✗" : String(option.index + 1)
                                color: option.answered && (option.correct || option.chosen) ? "white" : theme.subtle
                                font.family: theme.mono
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                        }
                        RichLabel {
                            Layout.fillWidth: true
                            raw: option.modelData
                        }
                    }
                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !option.answered
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(option.index)
                    }
                }
            }

            Rectangle {
                visible: root.choice >= 0
                readonly property bool isRight: root.current && root.choice === root.current.correta
                readonly property color tone: isRight ? theme.ok : theme.warn
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: explanation.implicitHeight + 30
                radius: theme.radius
                color: Qt.rgba(tone.r, tone.g, tone.b, 0.1)
                border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.35)

                ColumnLayout {
                    id: explanation
                    x: 16; y: 15
                    width: parent.width - 32
                    spacing: 8
                    Text {
                        text: parent.parent.isRight ? "CERTO" : "NÃO FOI DESSA VEZ"
                        color: parent.parent.tone
                        font.family: theme.mono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        raw: root.current ? root.current.explicacao : ""
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Ler a lição →"
                            color: theme.accent
                            font.pixelSize: 13
                            TapHandler { onTapped: if (root.current) root.openLesson(root.current.licao) }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                        Item { Layout.fillWidth: true }
                        AppButton {
                            highlighted: true
                            text: root.position + 1 < root.questions.length ? "Próxima (Enter)" : "Ver resultado"
                            onClicked: root.advance()
                        }
                    }
                }
            }
        }
    }

    // Result.
    Flickable {
        anchors.fill: parent
        visible: root.mode === "result"
        contentHeight: resultColumn.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: resultColumn
            width: Math.min(parent.width - 80, 780)
            x: (parent.width - width) / 2
            y: 40
            spacing: 14

            readonly property real ratio: root.score / Math.max(1, root.questions.length)

            Text {
                text: root.chapterTitle.toUpperCase()
                color: theme.subtle
                font.family: theme.mono
                font.pixelSize: 11
                font.letterSpacing: 1
            }
            Text {
                text: root.score + " de " + root.questions.length
                color: resultColumn.ratio >= 0.75 ? theme.ok : resultColumn.ratio >= 0.5 ? theme.warn : theme.danger
                font.pixelSize: 48
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: resultColumn.ratio === 1 ? "Gabaritou. Esse capítulo está firme."
                    : resultColumn.ratio >= 0.75 ? "Muito bom. Revise os poucos pontos abaixo."
                    : resultColumn.ratio >= 0.5 ? "No caminho. Releia as lições ligadas aos erros e refaça daqui a uns dias."
                    : "Vale reler o capítulo antes de refazer. Errar aqui é barato; em produção, não."
                color: theme.subtle
                font.pixelSize: 15
            }
            RowLayout {
                spacing: 10
                AppButton { highlighted: true; text: "Refazer"; onClicked: root.start(root.chapterId, root.chapterTitle) }
                AppButton { flat: true; text: "Voltar aos quizzes"; onClicked: root.mode = "menu" }
            }

            Text {
                visible: root.misses.length > 0
                Layout.topMargin: 14
                text: "Para revisar"
                color: theme.foreground
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Repeater {
                model: root.misses
                Card {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    RichLabel {
                        Layout.fillWidth: true
                        raw: modelData.pergunta
                        font.weight: Font.DemiBold
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        raw: "**Resposta:** " + modelData.opcoes[modelData.correta]
                        color: theme.ok
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Ler a lição →"
                        color: theme.accent
                        font.pixelSize: 13
                        TapHandler { onTapped: root.openLesson(modelData.licao) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}
