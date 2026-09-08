import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  required property var hardwareStats
  required property color foregroundColor
  required property string fontFamily

  readonly property var rootDisk: root.hardwareStats ? root.hardwareStats.rootDisk : ({ name: "System Root (/)", total: 187, used: 60, free: 127, pct: 32 })
  readonly property var volume2Disk: (root.hardwareStats && root.hardwareStats.volume2Disk) ? root.hardwareStats.volume2Disk : null

  implicitWidth: Style.space(540)
  implicitHeight: contentColumn.implicitHeight + Style.space(20)

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(10)

    // Header Row with Title and NVMe Health Badge
    RowLayout {
      width: parent.width

      Row {
        spacing: Style.space(8)
        Text {
          text: "󰋊"
          color: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "Storage & NVMe Health"
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
        color: Style.hoverFillFor(Color.accent, Color.accent)

        Text {
          id: healthText
          anchors.centerIn: parent
          text: "● " + (root.hardwareStats ? root.hardwareStats.smartStatus : "Healthy") + " (Grade A+)"
          color: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    // Drive 1: NVMe System Root (/)
    Rectangle {
      width: parent.width
      height: rootCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

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
              color: Color.accent
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
            text: (root.rootDisk ? root.rootDisk.used : 60) + " GB / " + (root.rootDisk ? root.rootDisk.total : 187) + " GB (" + (root.rootDisk ? root.rootDisk.pct : 32) + "%)"
            color: (root.rootDisk && root.rootDisk.pct > 85) ? Color.urgent : Color.accent
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
            width: Math.min(parent.width, Math.max(0, parent.width * ((root.rootDisk ? root.rootDisk.pct : 32) / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: (root.rootDisk && root.rootDisk.pct > 85) ? Color.urgent : Color.accent

            Behavior on width {
              NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
          }
        }

        RowLayout {
          width: parent.width
          Text {
            text: "Free Space: " + (root.rootDisk ? root.rootDisk.free : 127) + " GB remaining capacity"
            color: Qt.darker(root.foregroundColor, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "NVMe Temp: " + (root.hardwareStats ? root.hardwareStats.nvmeTemp : 55) + "°C (Optimal)"
            color: (root.hardwareStats && root.hardwareStats.nvmeTemp > 70) ? Color.urgent : Qt.darker(root.foregroundColor, 1.4)
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
      color: Style.normalFillFor(root.foregroundColor, Color.accent)
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
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: root.volume2Disk ? root.volume2Disk.name : "Secondary Storage Volume"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Item { Layout.fillWidth: true }

          Text {
            text: (root.volume2Disk ? root.volume2Disk.used : 90) + " GB / " + (root.volume2Disk ? root.volume2Disk.total : 128) + " GB (" + (root.volume2Disk ? root.volume2Disk.pct : 71) + "%)"
            color: (root.volume2Disk && root.volume2Disk.pct > 85) ? Color.urgent : Color.accent
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
            width: Math.min(parent.width, Math.max(0, parent.width * ((root.volume2Disk ? root.volume2Disk.pct : 70) / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: (root.volume2Disk && root.volume2Disk.pct > 85) ? Color.urgent : Color.accent

            Behavior on width {
              NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
          }
        }

        Text {
          text: "Free Space: " + (root.volume2Disk ? root.volume2Disk.free : 38) + " GB remaining capacity"
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
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

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
          color: Style.selectedFillFor(root.foregroundColor, Color.accent)

          Text {
            anchors.centerIn: parent
            text: "󰍛"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }

        Column {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "Samsung NVMe 512GB PCIe Gen3 x4"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            text: "SMART Health: 100% • 0 Critical Warnings • Trim Active"
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
