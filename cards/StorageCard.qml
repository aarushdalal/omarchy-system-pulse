import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as OmarchyPalette
import qs.Ui
import "../services/StorageState.js" as StorageState

Item {
  id: root

  required property var hardwareStats
  required property color foregroundColor
  required property string fontFamily

  readonly property var storageView: root.hardwareStats && root.hardwareStats.storageState
      ? root.hardwareStats.storageState : StorageState.snapshot(null, 0, Date.now(), 5000, "", false)
  readonly property var rootDisk: storageView.root
  readonly property var volume2Disk: storageView.volume2
  readonly property bool previousSample: storageView.state === "stale" || storageView.state === "error"

  implicitWidth: Style.space(540)
  implicitHeight: contentColumn.implicitHeight + Style.space(20)

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(10)

    // Header reports evidence availability, never an inferred health grade
    RowLayout {
      width: parent.width

      Row {
        spacing: Style.space(8)
        Text {
          text: "󰋊"
          color: OmarchyPalette.Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "Storage Telemetry"
          color: root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Item { Layout.fillWidth: true }

      // Health Pill
      Rectangle {
        height: Style.space(24)
        width: healthText.implicitWidth + Style.space(16)
        radius: Style.cornerRadius
        color: Style.hoverFillFor(OmarchyPalette.Color.accent, OmarchyPalette.Color.accent)

        Text {
          id: healthText
          anchors.centerIn: parent
          text: "● " + root.storageView.title
          textFormat: Text.PlainText
          color: root.storageView.state === "error" ? OmarchyPalette.Color.urgent : root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Text {
      width: parent.width
      text: root.storageView.detail
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    // Drive 1: NVMe System Root (/)
    Rectangle {
      width: parent.width
      height: rootCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, OmarchyPalette.Color.accent)

      Column {
        id: rootCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        RowLayout {
          width: parent.width

          Row {
            spacing: Style.space(6)
            Text {
              text: "󰋊"
              color: OmarchyPalette.Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "System Root Partition (/)"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            text: StorageState.capacityText(root.rootDisk) + (root.previousSample && root.rootDisk ? " · previous" : "")
            textFormat: Text.PlainText
            color: (root.rootDisk && root.rootDisk.pct > 85) ? OmarchyPalette.Color.urgent : OmarchyPalette.Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }
        }

        // Capacity Bar
        Rectangle {
          width: parent.width
          height: Style.space(8)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)
          clip: true

          Rectangle {
            width: Math.min(parent.width, Math.max(0, parent.width * ((root.rootDisk ? root.rootDisk.pct : 0) / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: (root.rootDisk && root.rootDisk.pct > 85) ? OmarchyPalette.Color.urgent : OmarchyPalette.Color.accent

            Behavior on width {
              NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
          }
        }

        RowLayout {
          width: parent.width
          Text {
            text: root.rootDisk ? "Free Space: " + root.rootDisk.free + " GiB" : "Free space unavailable"
            color: Qt.darker(root.foregroundColor, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.storageView.nvmeTemp !== null ? "NVMe Temp: " + root.storageView.nvmeTemp + "°C" : "NVMe Temp: unavailable"
            color: (root.storageView.nvmeTemp !== null && root.storageView.nvmeTemp > 70) ? OmarchyPalette.Color.urgent : Qt.darker(root.foregroundColor, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    // Drive 2: User Volume or Secondary Partition
    Rectangle {
      width: parent.width
      height: volCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, OmarchyPalette.Color.accent)
      visible: root.volume2Disk !== null

      Column {
        id: volCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        RowLayout {
          width: parent.width

          Row {
            spacing: Style.space(6)
            Text {
              text: "󰉉"
              color: OmarchyPalette.Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: root.volume2Disk ? root.volume2Disk.name : "Secondary Storage Volume"
              textFormat: Text.PlainText
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            text: StorageState.capacityText(root.volume2Disk) + (root.previousSample ? " · previous" : "")
            textFormat: Text.PlainText
            color: (root.volume2Disk && root.volume2Disk.pct > 85) ? OmarchyPalette.Color.urgent : OmarchyPalette.Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }
        }

        // Capacity Bar
        Rectangle {
          width: parent.width
          height: Style.space(8)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)
          clip: true

          Rectangle {
            width: Math.min(parent.width, Math.max(0, parent.width * ((root.volume2Disk ? root.volume2Disk.pct : 0) / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: (root.volume2Disk && root.volume2Disk.pct > 85) ? OmarchyPalette.Color.urgent : OmarchyPalette.Color.accent

            Behavior on width {
              NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
          }
        }

        Text {
          text: root.volume2Disk ? "Free Space: " + root.volume2Disk.free + " GiB" : "Free space unavailable"
          color: Qt.darker(root.foregroundColor, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // Hardware Specs Summary Card
    Rectangle {
      width: parent.width
      height: specsRow.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, OmarchyPalette.Color.accent)

      RowLayout {
        id: specsRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(12)

        Rectangle {
          width: Style.space(38)
          height: Style.space(38)
          radius: Style.cornerRadius
          color: Style.selectedFillFor(root.foregroundColor, OmarchyPalette.Color.accent)

          Text {
            anchors.centerIn: parent
            text: "󰍛"
            color: OmarchyPalette.Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "Root filesystem measurements"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: root.storageView.smartText
            textFormat: Text.PlainText
            color: Qt.darker(root.foregroundColor, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }
        }
      }
    }
  }
}
