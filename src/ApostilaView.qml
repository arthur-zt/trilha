import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root

    signal openTerm(string term)
    signal startQuiz(string chapterId)

    property string currentId: backend.lastLesson !== "" ? backend.lastLesson : backend.firstLessonOf("")
    readonly property var lesson: backend.lesson(currentId)
    readonly property bool read: (backend.revision, backend.isRead(currentId))

    function show(id) {
        if (!id)
            return
        currentId = id
        backend.openLesson(id)
        page.contentY = 0
        var index = backend.lessonIndex
        for (var i = 0; i < index.length; i++)
            if (index[i].id === id) { toc.positionViewAtIndex(i, ListView.Contain); break }
    }
    function next() { show(lesson.proxima) }
    function previous() { show(lesson.anterior) }
    // Space: done reading this one, on to the next.
    function primary() {
        backend.setRead(currentId, true)
        if (lesson.proxima)
            next()
    }

    Shortcut { sequence: "Alt+Right"; enabled: root.visible; context: Qt.ApplicationShortcut; onActivated: root.next() }
    Shortcut { sequence: "Alt+Left"; enabled: root.visible; context: Qt.ApplicationShortcut; onActivated: root.previous() }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 290
            Layout.fillHeight: true
            color: theme.background

            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.border }

            ListView {
                id: toc
                anchors.fill: parent
                anchors.margins: 10
                anchors.rightMargin: 11
                model: backend.lessonIndex
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool chapter: modelData.tipo === "cap"
                    readonly property bool current: !chapter && modelData.id === root.currentId
                    readonly property bool done: !chapter && (backend.revision, backend.isRead(modelData.id))

                    width: ListView.view.width
                    height: chapter ? chapterRow.implicitHeight + (index === 0 ? 10 : 26) : lessonRow.implicitHeight + 14
                    radius: theme.radius
                    color: current ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
                                   : area.containsMouse && !chapter ? theme.raised : "transparent"

                    RowLayout {
                        id: chapterRow
                        visible: entry.chapter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        x: 10
                        width: parent.width - 20
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.numero + " · " + entry.modelData.titulo
                            color: theme.foreground
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: entry.chapter
                            text: entry.chapter ? (backend.revision, backend.chapterRead(entry.modelData.id)) + "/"
                                                  + chapterSize(entry.modelData.id) : ""
                            color: theme.subtle
                            font.family: theme.mono
                            font.pixelSize: 11
                            function chapterSize(id) {
                                var chapters = backend.chapters
                                for (var i = 0; i < chapters.length; i++)
                                    if (chapters[i].id === id) return chapters[i].licoes
                                return 0
                            }
                        }
                    }

                    RowLayout {
                        id: lessonRow
                        visible: !entry.chapter
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        width: parent.width - 20
                        spacing: 8
                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: entry.done ? "✓" : "○"
                            color: entry.done ? theme.ok : theme.subtle
                            font.pixelSize: 13
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.titulo
                            color: entry.current ? theme.foreground : theme.subtle
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        enabled: !entry.chapter
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.show(entry.modelData.id)
                    }
                }
            }
        }

        Flickable {
            id: page
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 100
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: content
                width: Math.min(page.width - 96, 780)
                x: (page.width - width) / 2
                y: 44
                spacing: 18

                Text {
                    text: ("Capítulo " + root.lesson.capituloNumero + " · " + root.lesson.capituloTitulo
                           + " · lição " + root.lesson.posicao + " de " + root.lesson.totalCapitulo).toUpperCase()
                    color: theme.subtle
                    font.family: theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: -8
                    text: root.lesson.titulo || ""
                    color: theme.foreground
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: root.lesson.blocos || []
                    LessonBlock {
                        required property var modelData
                        Layout.fillWidth: true
                        block: modelData
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.topMargin: 16; implicitHeight: 1; color: theme.border }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    AppButton {
                        visible: !!root.lesson.anterior
                        flat: true
                        text: "← Anterior"
                        onClicked: root.previous()
                    }
                    Item { Layout.fillWidth: true }
                    AppButton {
                        text: root.read ? "Lida ✓" : "Marcar como lida"
                        flat: root.read
                        toned: root.read; tone: theme.ok
                        onClicked: backend.setRead(root.currentId, !root.read)
                    }
                    AppButton {
                        visible: !!root.lesson.proxima
                        highlighted: true
                        text: "Próxima →"
                        onClicked: { backend.setRead(root.currentId, true); root.next() }
                    }
                    AppButton {
                        visible: !root.lesson.proxima || root.lesson.posicao === root.lesson.totalCapitulo
                        flat: true
                        text: "Fazer o quiz do capítulo"
                        onClicked: root.startQuiz(root.lesson.capituloId)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!root.lesson.proxima
                    text: "A seguir: " + (root.lesson.proximaTitulo || "") + "   ·   Espaço marca como lida e avança"
                    color: theme.subtle
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
