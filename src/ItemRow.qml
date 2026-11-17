import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One checklist item of the trilha.
RowLayout {
    id: row

    property var item: ({})
    property string phaseLabel: ""
    readonly property bool done: (backend.revision, backend.isDone(item.id))
    readonly property color tone: item.tipo === "lab" ? theme.info : item.tipo === "real" ? theme.warn : theme.subtle

    spacing: 10

    CheckBox {
        id: box
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: -8
        checked: row.done
        Material.accent: theme.ok
        onToggled: {
            backend.toggleItem(row.item.id)
            checked = Qt.binding(function() { return row.done })
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 2
        Text {
            Layout.fillWidth: true
            text: row.item.texto || ""
            color: row.done ? theme.subtle : theme.foreground
            font.pixelSize: 15
            font.strikeout: row.done
            wrapMode: Text.Wrap
            TapHandler { onTapped: backend.toggleItem(row.item.id) }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        Text {
            visible: !!row.item.sub || row.phaseLabel !== ""
            Layout.fillWidth: true
            text: row.phaseLabel !== "" ? row.phaseLabel + (row.item.sub ? " · " + row.item.sub : "") : (row.item.sub || "")
            color: theme.subtle
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
        Text {
            visible: !!row.item.link
            text: "Abrir referência ↗"
            color: theme.accent
            font.pixelSize: 13
            font.underline: linkHover.hovered
            HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Qt.openUrlExternally(row.item.link) }
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignTop
        spacing: 4
        Chip {
            Layout.alignment: Qt.AlignRight
            text: row.item.tipo === "real" ? "ambiente" : (row.item.tipo || "")
            tone: row.tone
        }
        Text {
            Layout.alignment: Qt.AlignRight
            visible: row.done
            text: "feito " + (backend.revision, backend.doneDate(row.item.id))
            color: theme.ok
            font.family: theme.mono
            font.pixelSize: 11
        }
    }
}
