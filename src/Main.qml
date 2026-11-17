import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win

    width: 1320
    height: 860
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    title: "Trilha"
    color: theme.background
    font.family: theme.sans

    Material.theme: theme.dark ? Material.Dark : Material.Light
    Material.accent: theme.accent
    Material.foreground: theme.foreground
    Material.roundedScale: theme.radius

    readonly property var sections: ["Início", "Trilha", "Apostila", "Glossário", "Flashcards", "Quiz"]
    property int view: 0
    // Single-key shortcuts stay quiet while a text field has the focus.
    readonly property bool typing: activeFocusItem !== null && activeFocusItem.cursorPosition !== undefined

    function openLesson(id) { apostila.show(id); view = 2 }
    function openChapter(id) { openLesson(backend.firstLessonOf(id)) }
    function openTerm(term) { view = 3; glossario.focusTerm(term) }
    function startQuiz(chapterId) {
        var chapters = backend.chapters
        for (var i = 0; i < chapters.length; i++)
            if (chapters[i].id === chapterId) { quiz.start(chapterId, chapters[i].titulo); break }
        view = 5
    }
    function primary() {
        if (view === 2) apostila.primary()
        else if (view === 4) cards.primary()
        else if (view === 5) quiz.primary()
    }

    Shortcut { sequence: "Ctrl+1"; context: Qt.ApplicationShortcut; onActivated: win.view = 0 }
    Shortcut { sequence: "Ctrl+2"; context: Qt.ApplicationShortcut; onActivated: win.view = 1 }
    Shortcut { sequence: "Ctrl+3"; context: Qt.ApplicationShortcut; onActivated: win.view = 2 }
    Shortcut { sequence: "Ctrl+4"; context: Qt.ApplicationShortcut; onActivated: win.view = 3 }
    Shortcut { sequence: "Ctrl+5"; context: Qt.ApplicationShortcut; onActivated: win.view = 4 }
    Shortcut { sequence: "Ctrl+6"; context: Qt.ApplicationShortcut; onActivated: win.view = 5 }
    Shortcut { sequence: "Ctrl+K"; context: Qt.ApplicationShortcut; onActivated: search.open() }
    Shortcut { sequence: "/"; enabled: !win.typing; context: Qt.ApplicationShortcut; onActivated: search.open() }
    Shortcut { sequence: "?"; enabled: !win.typing; context: Qt.ApplicationShortcut; onActivated: help.visible ? help.close() : help.open() }
    Shortcut { sequence: "Q"; enabled: !win.typing && !search.visible; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; enabled: !win.typing && !search.visible && !help.visible; context: Qt.ApplicationShortcut; onActivated: win.primary() }

    // Right-to-left languages would mirror the window; the content is
    // Portuguese, but the layout stays ready for it.
    RowLayout {
        anchors.fill: parent
        spacing: 0
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: theme.surface

            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.border }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.rightMargin: 15
                spacing: 4

                RowLayout {
                    Layout.topMargin: 6
                    Layout.bottomMargin: 18
                    Layout.leftMargin: 4
                    spacing: 10
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: theme.radius
                        color: theme.accent
                        // The mark: three stops on a path.
                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    width: 6; height: 6; radius: 3
                                    y: [8, 2, 5][index]
                                    color: theme.accentForeground
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: "Trilha"; color: theme.foreground; font.pixelSize: 18; font.weight: Font.Bold }
                        Text { text: "Infra & DevOps"; color: theme.subtle; font.pixelSize: 12 }
                    }
                }

                Repeater {
                    model: win.sections
                    NavButton {
                        required property string modelData
                        required property int index
                        label: modelData
                        hint: "^" + (index + 1)
                        current: win.view === index
                        badge: {
                            if (index !== 4) return ""
                            backend.revision
                            var n = backend.dueCount()
                            return n === 0 ? "" : n > 99 ? "99+" : String(n)
                        }
                        onClicked: win.view = index
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: searchHint.implicitHeight + 16
                    radius: theme.radius
                    color: searchArea.containsMouse ? theme.raised : "transparent"
                    border.color: theme.border
                    Text {
                        id: searchHint
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: "Buscar…"
                        color: theme.subtle
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        text: "Ctrl+K"
                        color: theme.subtle
                        opacity: 0.6
                        font.family: theme.mono
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: searchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: search.open()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.margins: 4
                    spacing: 6
                    readonly property real ratio: (backend.revision, backend.itemsDone() / Math.max(1, backend.itemsTotal()))
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Progresso da trilha"; color: theme.subtle; font.pixelSize: 12; Layout.fillWidth: true }
                        Text {
                            text: Math.round(parent.parent.ratio * 100) + "%"
                            color: theme.foreground
                            font.family: theme.mono
                            font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: theme.raised
                        Rectangle {
                            width: parent.width * parent.parent.ratio
                            height: parent.height
                            radius: 2
                            color: theme.accent
                        }
                    }
                    Text {
                        Layout.topMargin: 4
                        text: "? atalhos · Q sair"
                        color: theme.subtle
                        opacity: 0.6
                        font.pixelSize: 11
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.view

            HomeView {
                onOpenLesson: (id) => win.openLesson(id)
                onOpenChapter: (id) => win.openChapter(id)
                onGoTo: (index) => win.view = index
            }
            TrilhaView {
                id: trilha
                onOpenChapter: (id) => win.openChapter(id)
            }
            ApostilaView {
                id: apostila
                onStartQuiz: (id) => win.startQuiz(id)
            }
            GlossarioView {
                id: glossario
                onOpenLesson: (id) => win.openLesson(id)
            }
            CardsView {
                id: cards
                onOpenLesson: (id) => win.openLesson(id)
            }
            QuizView {
                id: quiz
                onOpenLesson: (id) => win.openLesson(id)
            }
        }
    }

    // Problems loading content or saving progress are said in the window.
    Rectangle {
        visible: backend.error !== ""
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        width: Math.min(parent.width - 80, errorText.implicitWidth + 32)
        implicitHeight: errorText.implicitHeight + 20
        radius: theme.radius
        color: Qt.rgba(theme.danger.r, theme.danger.g, theme.danger.b, 0.9)
        Text {
            id: errorText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 32)
            text: backend.error
            color: "white"
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
    }

    SearchOverlay {
        id: search
        onPicked: (kind, target) => {
            if (kind === "licao") win.openLesson(target)
            else if (kind === "termo") win.openTerm(target)
            else if (kind === "item") { win.view = 1; trilha.focusPhase(target) }
        }
    }
    HelpOverlay { id: help }
}
