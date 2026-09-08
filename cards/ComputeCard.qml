import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  required property var hardwareStats
  required property color foregroundColor
  required property string fontFamily

  readonly property int cpuBusyPct: root.hardwareStats ? root.hardwareStats.cpuBusyPercent : 0
  readonly property int cpuCompPct: root.hardwareStats ? root.hardwareStats.cpuComputePercent : 0
  readonly property string cpuFreq: root.hardwareStats ? root.hardwareStats.cpuFreqGhz : "3.5"
  readonly property int cpuT: root.hardwareStats ? root.hardwareStats.cpuTemp : 0

  readonly property int gpuPct: root.hardwareStats ? root.hardwareStats.gpuPercent : 0
  readonly property int gpuVramU: root.hardwareStats ? root.hardwareStats.gpuVramUsed : 0
  readonly property int gpuVramTot: root.hardwareStats ? root.hardwareStats.gpuVramTotal : 512
  readonly property int gpuVramPct: root.hardwareStats ? root.hardwareStats.gpuVramPercent : 0
  readonly property int gpuGttU: root.hardwareStats ? root.hardwareStats.gpuGttUsed : 0
  readonly property int gpuT: root.hardwareStats ? root.hardwareStats.gpuTemp : 0
  readonly property int gpuW: root.hardwareStats ? root.hardwareStats.gpuPower : 0

  readonly property int ramUsedMB: root.hardwareStats ? root.hardwareStats.ramUsed : 0
  readonly property int ramTotalMB: root.hardwareStats ? root.hardwareStats.ramTotal : 0
  readonly property int ramPct: root.hardwareStats ? root.hardwareStats.ramPercent : 0
  readonly property int swapUsedMB: root.hardwareStats ? root.hardwareStats.swapUsed : 0
  readonly property int swapTotalMB: root.hardwareStats ? root.hardwareStats.swapTotal : 0
  readonly property int swapPct: root.hardwareStats ? root.hardwareStats.swapPercent : 0

  readonly property int totalW: root.hardwareStats ? root.hardwareStats.totalPower : 22

  implicitWidth: Style.space(540)
  implicitHeight: contentColumn.implicitHeight + Style.space(20)

  Process {
    id: monitorProc
    command: ["${XDG_BIN_HOME:-$HOME/.local/bin}/omarchy-system-monitor"]
  }

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(10)

    // Header Row with Title and Dynamic Turbo Badge
    RowLayout {
      width: parent.width

      Row {
        spacing: Style.space(8)
        Text {
          text: "󰍛"
          color: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "Compute & Power Matrix"
          color: root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Item { Layout.fillWidth: true }

      // System Monitor Button
      Rectangle {
        height: Style.space(24)
        width: monitorBtnRow.implicitWidth + Style.space(16)
        radius: Style.cornerRadius
        color: monitorMouse.containsMouse
          ? Style.hoverFillFor(Color.accent, Color.accent)
          : Style.normalFillFor(root.foregroundColor, Color.accent)
        border.color: (root.hardwareStats && !root.hardwareStats.btopInstalled) ? Color.urgent : Style.hoverFillFor(Color.accent, Color.accent)
        border.width: 1

        Row {
          id: monitorBtnRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: (root.hardwareStats && !root.hardwareStats.btopInstalled) ? "󰅚" : "󰍛"
            color: (root.hardwareStats && !root.hardwareStats.btopInstalled) ? Color.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: (root.hardwareStats && !root.hardwareStats.btopInstalled) ? "Install btop" : "System Monitor"
            color: (root.hardwareStats && !root.hardwareStats.btopInstalled) ? Color.urgent : root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          id: monitorMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            monitorProc.running = false
            monitorProc.running = true
          }
        }
      }

      // Turbo / Power Pill
      Rectangle {
        height: Style.space(24)
        width: turboText.implicitWidth + Style.space(16)
        radius: Style.cornerRadius
        color: Style.hoverFillFor(Color.accent, Color.accent)

        Text {
          id: turboText
          anchors.centerIn: parent
          text: "⚡ " + root.cpuFreq + " GHz Turbo • " + root.totalW + "W Total"
          color: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    // Missing btop dependency warning banner
    Rectangle {
      width: parent.width
      height: Style.space(34)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
      border.color: Color.urgent
      border.width: 1
      visible: root.hardwareStats && !root.hardwareStats.btopInstalled

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(8)

        Text {
          text: "󰅚"
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          Layout.fillWidth: true
          text: "btop is not installed. Please install it by running: sudo pacman -S btop"
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          elide: Text.ElideRight
        }

        Rectangle {
          height: Style.space(22)
          width: installBtopText.implicitWidth + Style.space(14)
          radius: Style.cornerRadius - 2
          color: Color.urgent

          Text {
            id: installBtopText
            anchors.centerIn: parent
            text: "Install btop"
            color: "#ffffff"
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              monitorProc.running = false
              monitorProc.running = true
            }
          }
        }
      }
    }

    // CPU Section (AMD Ryzen 7 PRO 5850U - 16 Threads)
    Rectangle {
      width: parent.width
      height: cpuCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      Column {
        id: cpuCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        RowLayout {
          width: parent.width
          Text {
            text: "CPU: AMD Ryzen 7 PRO 5850U (16T)"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.cpuBusyPct + "% Total Busy (" + root.cpuCompPct + "% Calc)"
            color: root.cpuBusyPct > 85 ? Color.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        // Dual-Tone Active CPU Bar (Compute + IO-Wait)
        Rectangle {
          width: parent.width
          height: Style.space(8)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)
          clip: true

          // Total Busy (Light Accent / Warning)
          Rectangle {
            width: Math.min(parent.width, Math.max(0, parent.width * (root.cpuBusyPct / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: root.cpuBusyPct > 85 ? Color.urgent : Qt.darker(Color.accent, 1.4)
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          }

          // Active Compute (Solid Vibrant Accent)
          Rectangle {
            width: Math.min(parent.width, Math.max(0, parent.width * (root.cpuCompPct / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: Color.accent
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          }
        }

        RowLayout {
          width: parent.width
          Text {
            text: "Clock Speed: " + root.cpuFreq + " GHz Max Turbo • 16 Active Threads"
            color: Qt.darker(root.foregroundColor, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "Hotspot: " + root.cpuT + "°C"
            color: root.cpuT > 85 ? Color.urgent : (root.cpuT > 75 ? "#e5c07b" : Qt.darker(root.foregroundColor, 1.4))
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: root.cpuT > 85
          }
        }
      }
    }

    // GPU Section (AMD Radeon APU Graphics)
    Rectangle {
      width: parent.width
      height: gpuCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      Column {
        id: gpuCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        RowLayout {
          width: parent.width
          Text {
            text: "GPU: AMD Radeon Vega Graphics (APU)"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.gpuPct + "% 3D Engine • " + root.gpuT + "°C • " + root.gpuW + "W PPT"
            color: root.gpuT > 85 ? Color.urgent : (root.gpuT > 75 ? "#e5c07b" : Color.accent)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        // VRAM Allocation Bar
        Rectangle {
          width: parent.width
          height: Style.space(8)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)
          clip: true

          Rectangle {
            width: Math.min(parent.width, Math.max(0, parent.width * (root.gpuVramPct / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: root.gpuVramPct > 90 ? Color.urgent : Color.accent
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          }
        }

        Text {
          text: "Dedicated VRAM: " + root.gpuVramU + " / " + root.gpuVramTot + " MB (" + root.gpuVramPct + "%) • Shared GTT: " + (root.gpuGttU / 1024).toFixed(1) + " GB"
          color: Qt.darker(root.foregroundColor, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // RAM & Swap Section
    Rectangle {
      width: parent.width
      height: ramCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      Column {
        id: ramCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        RowLayout {
          width: parent.width
          Text {
            text: "RAM: " + (root.ramUsedMB / 1024).toFixed(1) + " / " + (root.ramTotalMB / 1024).toFixed(1) + " GB (" + root.ramPct + "%)"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "ZRAM: " + (root.swapUsedMB / 1024).toFixed(1) + " / " + (root.swapTotalMB / 1024).toFixed(1) + " GB (" + root.swapPct + "%)"
            color: Qt.darker(root.foregroundColor, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(6)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)
          clip: true

          Rectangle {
            width: Math.min(parent.width, Math.max(0, parent.width * (root.ramPct / 100)))
            height: parent.height
            radius: Style.cornerRadius
            color: root.ramPct > 85 ? Color.urgent : Color.accent
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
          }
        }
      }
    }

    // Live 20-Point Sparkline Activity Waveform with Glowing Peak Dots
    Rectangle {
      width: parent.width
      height: Style.space(50)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)
      clip: true

      Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(6)
        spacing: Style.space(4)

        Repeater {
          model: 20

          Rectangle {
            required property int index
            readonly property var hist: (root.hardwareStats && root.hardwareStats.cpuHistory) ? root.hardwareStats.cpuHistory : []
            readonly property real val: (hist.length > index) ? hist[index] : 20
            width: (parent.width - Style.space(80)) / 20
            height: Math.max(4, Math.min(Style.space(36), (val / 100) * Style.space(36)))
            anchors.bottom: parent.bottom
            radius: 2
            color: Color.accent
            opacity: 0.35 + (index / 20.0) * 0.65

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
          }
        }
      }

      Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.space(6)
        text: "LIVE CPU ACTIVITY HISTORY (20-POINT SAMPLING)"
        color: Qt.darker(root.foregroundColor, 1.6)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 2
        font.bold: true
      }
    }
  }
}
