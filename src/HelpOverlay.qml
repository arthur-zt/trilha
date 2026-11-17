import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// "?": every shortcut in one place.
Popup {
    id: popup

    readonly property var groups: [
        { title: "Geral", keys: [
            ["Ctrl+1 … 6", "Início, Trilha, Apostila, Glossário, Flashcards, Quiz"],
            ["Ctrl+K  ou  /", "Buscar em tudo"],
            ["?", "Mostrar ou esconder os atalhos"],
            ["Q", "Sair (o progresso já está salvo)"],
            ["Esc", "Fechar janela aberta"] ] },
        { title: "Apostila", keys: [
            ["Espaço", "Marcar como lida e ir para a próxima"],
            ["Alt+← / Alt+→", "Lição anterior / próxima"] ] },
        { title: "Flashcards", keys: [
            ["Espaço", "Começar a revisão ou virar o cartão"],
            ["← / →", "Errei / Acertei"] ] },
        { title: "Quiz", keys: [
            ["1 a 4", "Escolher a resposta"],
            ["Enter ou Espaço", "Próxima pergunta"] ] }
    ]

    parent: Overlay.overlay
    modal: true
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(parent.width - 80, 620)
    padding: 26

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
    background: Rectangle {
        color: theme.surface
        radius: theme.radius
        border.color: theme.border
    }

    contentItem: ColumnLayout {
        spacing: 16
        Text {
            text: "Atalhos"
            color: theme.foreground
            font.pixelSize: 22
            font.weight: Font.Bold
        }
        Repeater {
            model: popup.groups
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: modelData.title.toUpperCase()
                    color: theme.accent
                    font.family: theme.mono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
                Repeater {
                    model: modelData.keys
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 14
                        Text {
                            Layout.preferredWidth: 150
                            text: modelData[0]
                            color: theme.foreground
                            font.family: theme.mono
                            font.pixelSize: 13
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData[1]
                            color: theme.subtle
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
