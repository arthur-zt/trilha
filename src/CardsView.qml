import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root

    signal openLesson(string id)

    property var queue: []
    property int position: 0
    property bool flipped: false
    property bool animate: true
    property string mode: "start"   // start | session | done
    property int hits: 0
    property int wrong: 0
    property var repeated: ({})
    readonly property var current: mode === "session" && position < queue.length ? queue[position] : null
    readonly property var boxes: (backend.revision, backend.boxCounts())
    readonly property int due: (backend.revision, backend.dueCount())

    function start(cards) {
        if (cards.length === 0)
            return
        queue = cards
        position = 0
        flipped = false
        hits = 0
        wrong = 0
        repeated = ({})
        mode = "session"
    }
    function primary() {
        if (mode === "start") start(backend.dueCards(20))
        else if (mode === "done") mode = "start"
        else flipped = !flipped
    }
    function answer(knew) {
        if (!current || !flipped)
            return
        backend.answerCard(current.termo, knew)
        if (knew) {
            hits++
        } else {
            wrong++
            // A missed card comes back once at the end of the session.
            if (!repeated[current.termo]) {
                repeated[current.termo] = true
                var copy = queue.slice()
                copy.push(current)
                queue = copy
            }
        }
        // Turn the card back instantly, so the next answer never shows
        // during the flip.
        animate = false
        flipped = false
        animate = true
        if (position + 1 >= queue.length) mode = "done"
        else position++
    }

    Shortcut { sequence: "Left"; enabled: root.visible && root.flipped; context: Qt.ApplicationShortcut; onActivated: root.answer(false) }
    Shortcut { sequence: "Right"; enabled: root.visible && root.flipped; context: Qt.ApplicationShortcut; onActivated: root.answer(true) }

    // Start: what is due and how the boxes work.
    Flickable {
        anchors.fill: parent
        visible: root.mode === "start"
        contentHeight: startColumn.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: startColumn
            width: Math.min(parent.width - 80, 760)
            x: (parent.width - width) / 2
            y: 40
            spacing: 18

            Text {
                text: "Flashcards"
                color: theme.foreground
                font.pixelSize: 30
                font.weight: Font.Bold
            }
            RichLabel {
                Layout.fillWidth: true
                color: theme.subtle
                raw: "Cada termo do glossário vira um cartão. Acertou, ele sobe uma caixa e só volta mais tarde. Errou, volta para a caixa 1 e reaparece amanhã. É a **repetição espaçada** (sistema Leitner): você revisa mais o que sabe menos."
            }

            Card {
                Layout.fillWidth: true
                spacing: 18
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: String(root.due)
                            color: theme.foreground
                            font.pixelSize: 44
                            font.weight: Font.Bold
                        }
                        Text {
                            text: root.due === 1 ? "cartão para revisar hoje" : "cartões para revisar hoje"
                            color: theme.subtle
                            font.pixelSize: 14
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 8
                        AppButton {
                            Layout.fillWidth: true
                            highlighted: true
                            enabled: root.due > 0
                            text: "Revisar agora (Espaço)"
                            onClicked: root.start(backend.dueCards(20))
                        }
                        AppButton {
                            Layout.fillWidth: true
                            flat: true
                            text: "Praticar 20 aleatórios"
                            onClicked: root.start(backend.randomCards(20))
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: 6
                        ColumnLayout {
                            required property int index
                            readonly property int count: root.boxes[index] || 0
                            readonly property int most: Math.max.apply(null, root.boxes.concat([1]))
                            Layout.fillWidth: true
                            Layout.preferredWidth: 100
                            spacing: 6
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 90
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(3, 90 * parent.parent.count / parent.parent.most)
                                    radius: Math.min(4, theme.radius)
                                    color: parent.parent.index === 0 ? theme.raised
                                         : parent.parent.index >= 4 ? theme.ok : theme.info
                                    opacity: parent.parent.index === 0 ? 1 : 0.35 + parent.parent.index * 0.13
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: parent.count
                                color: theme.foreground
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: parent.index === 0 ? "Novos" : "Caixa " + parent.index
                                color: theme.subtle
                                font.pixelSize: 12
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: ["nunca vistos", "volta em 1 dia", "volta em 3 dias", "volta em 7 dias",
                                       "volta em 14 dias", "volta em 30 dias"][parent.index]
                                color: theme.subtle
                                opacity: 0.7
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }

    // Session: one card at a time.
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 720)
        visible: root.mode === "session"
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Cartão " + Math.min(root.position + 1, root.queue.length) + " de " + root.queue.length
                color: theme.subtle
                font.pixelSize: 14
            }
            Item { Layout.fillWidth: true }
            Text { text: "✓ " + root.hits; color: theme.ok; font.pixelSize: 14 }
            Text { text: "✗ " + root.wrong; color: theme.danger; font.pixelSize: 14; Layout.leftMargin: 10 }
            AppButton { flat: true; text: "Encerrar"; onClicked: root.mode = "done" }
        }

        Rectangle {
            id: card
            Layout.fillWidth: true
            Layout.preferredHeight: 380
            radius: theme.radius
            color: theme.surface
            border.width: 1
            border.color: root.flipped ? theme.accent : theme.border

            property real turn: root.flipped ? 180 : 0
            Behavior on turn { enabled: root.animate; NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }
            transform: Rotation {
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: card.turn
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.flipped = !root.flipped
            }

            // Front: the term.
            ColumnLayout {
                visible: card.turn < 90
                anchors.centerIn: parent
                width: parent.width - 80
                spacing: 10
                Chip {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.current ? root.current.categoria : ""
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.current ? root.current.termo : ""
                    color: theme.foreground
                    font.pixelSize: 42
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 18
                    text: "O que é? Pense na resposta e vire o cartão (Espaço)"
                    color: theme.subtle
                    font.pixelSize: 13
                }
            }

            // Back: the meaning, mirrored so it reads right after the turn.
            Item {
                visible: card.turn >= 90
                anchors.fill: parent
                transform: Rotation {
                    origin.x: card.width / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: 180
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 80
                    spacing: 12
                    RowLayout {
                        spacing: 10
                        Text {
                            text: root.current ? root.current.termo : ""
                            color: Qt.lighter(theme.accent, 1.4)
                            font.pixelSize: 22
                            font.weight: Font.Bold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.current ? (root.current.nome || "") : ""
                            color: theme.subtle
                            font.pixelSize: 14
                            font.italic: true
                            elide: Text.ElideRight
                        }
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        raw: root.current ? root.current.definicao : ""
                        font.pixelSize: 17
                    }
                    RichLabel {
                        Layout.fillWidth: true
                        visible: !!(root.current && root.current.exemplo)
                        raw: root.current && root.current.exemplo ? "**Na prática:** " + root.current.exemplo : ""
                        color: theme.subtle
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Ver na apostila →"
                        color: theme.accent
                        font.pixelSize: 13
                        TapHandler { onTapped: if (root.current) root.openLesson(root.current.licao) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14
            AppButton {
                visible: !root.flipped
                highlighted: true
                text: "Virar (Espaço)"
                onClicked: root.flipped = true
            }
            AppButton {
                visible: root.flipped
                text: "← Errei"
                toned: true; tone: theme.danger
                onClicked: root.answer(false)
            }
            AppButton {
                visible: root.flipped
                text: "Acertei →"
                toned: true; tone: theme.ok
                onClicked: root.answer(true)
            }
        }
    }

    // Done.
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.mode === "done"
        spacing: 14
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Sessão concluída"
            color: theme.foreground
            font.pixelSize: 28
            font.weight: Font.Bold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.hits + " acertos · " + root.wrong + " erros"
            color: theme.subtle
            font.pixelSize: 16
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 520
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.wrong === 0 ? "Tudo certo. Esses cartões só voltam daqui a alguns dias."
                                   : "Os que você errou voltam amanhã. Errar faz parte: é o que mostra o que revisar."
            color: theme.subtle
            font.pixelSize: 14
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 10
            AppButton {
                highlighted: true
                text: root.due > 0 ? "Mais " + Math.min(20, root.due) + " cartões" : "Praticar aleatórios"
                onClicked: root.start(root.due > 0 ? backend.dueCards(20) : backend.randomCards(20))
            }
            AppButton { flat: true; text: "Voltar"; onClicked: root.mode = "start" }
        }
    }
}
