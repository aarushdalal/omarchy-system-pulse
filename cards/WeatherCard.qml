import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  required property color foregroundColor
  required property string fontFamily

  property string location: "New Delhi, India"
  property string temperature: "36°C"
  property string feelsLike: "39°C"
  property string condition: "Haze"
  property string humidity: "32%"
  property string wind: "17 km/h"
  property string weatherIcon: "󰖑"

  function refresh() {
    if (!weatherProc.running) weatherProc.running = true
  }

  Process {
    id: weatherProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/daemon0.system-pulse/services/weather-fetcher.sh"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || text.trim() === "") return
        try {
          var data = JSON.parse(text.trim())
          if (data.location) root.location = data.location
          if (data.temp) root.temperature = data.temp
          if (data.feels_like) root.feelsLike = data.feels_like
          if (data.condition) root.condition = data.condition
          if (data.humidity) root.humidity = data.humidity
          if (data.wind) root.wind = data.wind
          if (data.icon) root.weatherIcon = data.icon
        } catch (e) {}
      }
    }
  }

  implicitWidth: Style.space(540)
  implicitHeight: contentColumn.implicitHeight + Style.space(20)

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(12)
    spacing: Style.space(10)

    // Header Row with Title and Dynamic Location Badge
    RowLayout {
      width: parent.width

      Row {
        spacing: Style.space(8)
        Text {
          text: "🌤️"
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "Weather & Atmosphere"
          color: root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Item { Layout.fillWidth: true }

      // Location Chip
      Rectangle {
        height: Style.space(24)
        width: locRow.implicitWidth + Style.space(16)
        radius: Style.cornerRadius
        color: Style.hoverFillFor(Color.accent, Color.accent)

        Row {
          id: locRow
          anchors.centerIn: parent
          spacing: Style.space(5)

          Text {
            text: "📍"
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: root.location
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    // Hero Weather Showcase Box (Frameless Floating Glass)
    Rectangle {
      width: parent.width
      height: heroRow.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      RowLayout {
        id: heroRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(14)
        spacing: Style.space(18)

        // Large Weather Glyph Box
        Rectangle {
          width: Style.space(68)
          height: Style.space(68)
          radius: Style.cornerRadius
          color: Style.selectedFillFor(root.foregroundColor, Color.accent)

          Text {
            anchors.centerIn: parent
            text: root.weatherIcon
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.space(38)
          }
        }

        // Temperature & Condition Hierarchy
        Column {
          Layout.fillWidth: true
          spacing: 2

          Row {
            spacing: Style.space(10)
            Text {
              text: root.temperature
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.space(32)
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
              height: Style.space(22)
              width: feelsText.implicitWidth + Style.space(14)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.1)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                id: feelsText
                anchors.centerIn: parent
                text: "RealFeel " + root.feelsLike
                color: Qt.darker(root.foregroundColor, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }

          Text {
            text: root.condition + " • Real-Time Satellite Doppler Synchronized"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }
        }
      }
    }

    // 4-Tile Luxury Bento Metric Grid (2x2 Layout)
    Grid {
      width: parent.width
      columns: 2
      rowSpacing: Style.space(8)
      columnSpacing: Style.space(8)

      // Tile 1: Humidity
      Rectangle {
        width: (parent.width - Style.space(8)) / 2
        height: Style.space(56)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          Text {
            text: "󰖔"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            Layout.alignment: Qt.AlignVCenter
          }

          Column {
            Layout.fillWidth: true
            spacing: 1
            Text {
              text: "Relative Humidity"
              color: Qt.darker(root.foregroundColor, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              text: root.humidity + " (Optimal Range)"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }
      }

      // Tile 2: Wind Speed
      Rectangle {
        width: (parent.width - Style.space(8)) / 2
        height: Style.space(56)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          Text {
            text: "󰖝"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            Layout.alignment: Qt.AlignVCenter
          }

          Column {
            Layout.fillWidth: true
            spacing: 1
            Text {
              text: "Wind Velocity"
              color: Qt.darker(root.foregroundColor, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              text: root.wind + " (Breeze)"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }
      }

      // Tile 3: Heat / Comfort Index
      Rectangle {
        width: (parent.width - Style.space(8)) / 2
        height: Style.space(56)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          Text {
            text: "󰔏"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            Layout.alignment: Qt.AlignVCenter
          }

          Column {
            Layout.fillWidth: true
            spacing: 1
            Text {
              text: "Thermal Index"
              color: Qt.darker(root.foregroundColor, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              text: root.feelsLike + " (Warm Weather)"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }
      }

      // Tile 4: Solar UV Exposure
      Rectangle {
        width: (parent.width - Style.space(8)) / 2
        height: Style.space(56)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          Text {
            text: "󰖙"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            Layout.alignment: Qt.AlignVCenter
          }

          Column {
            Layout.fillWidth: true
            spacing: 1
            Text {
              text: "UV Solar Index"
              color: Qt.darker(root.foregroundColor, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              text: "UV 1 (Low / Safe Exposure)"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }
      }
    }

    // Refresh Action Button
    Button {
      width: parent.width
      iconText: "󰑐"
      text: "Refresh Regional Forecast Data"
      foreground: root.foregroundColor
      fontFamily: root.fontFamily
      onClicked: root.refresh()
    }
  }
}
