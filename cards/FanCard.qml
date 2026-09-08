import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  required property var hardwareStats
  required property var fanService
  required property color foregroundColor
  required property string fontFamily

  property int selectedPointIndex: 2

  readonly property var currentPoint: (root.fanService && root.fanService.curve && root.fanService.curve.length > root.selectedPointIndex && root.fanService.curve[root.selectedPointIndex])
    ? root.fanService.curve[root.selectedPointIndex]
    : ({ temp: 62, speed: 50 })

  readonly property int calculatedRpm: root.fanService ? root.fanService.currentRpm : 3480
  readonly property int calculatedPercent: root.fanService ? root.fanService.currentPercent : 60
  readonly property int currentTemp: root.hardwareStats ? (root.hardwareStats.cpuTemp || 55) : 55

  implicitWidth: Style.space(540)
  implicitHeight: contentColumn.implicitHeight + Style.space(20)

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(14)
    spacing: Style.space(10)

    // Hero Section: Fan Tachometer + Live RPM Gauge + Max Test Mode Button
    Rectangle {
      width: parent.width
      height: Style.space(92)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(14)

        // Animated Spinning Fan Badge with Ambient Halo
        Rectangle {
          width: Style.space(68)
          height: Style.space(68)
          radius: Style.cornerRadius
          color: (root.fanService && root.fanService.maxTestMode)
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
            : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.06)

          border.width: (root.fanService && root.fanService.maxTestMode) ? 1 : 0
          border.color: Color.accent

          Text {
            id: fanIcon
            text: "󰈐"
            color: (root.calculatedPercent > 0) ? Color.accent : Qt.darker(root.foregroundColor, 2.0)
            font.family: root.fontFamily
            font.pixelSize: Style.font.title + 10
            anchors.centerIn: parent

            RotationAnimator on rotation {
              from: 0
              to: 360
              duration: (root.calculatedPercent > 0)
                ? Math.max(180, 2200 - (root.calculatedPercent * 20))
                : 2400
              loops: Animation.Infinite
              running: root.calculatedPercent > 0
            }
          }
        }

        // Live RPM & Duty Cycle Readout
        Column {
          Layout.fillWidth: true
          spacing: Style.space(4)

          Row {
            spacing: Style.space(8)

            Text {
              text: root.calculatedRpm.toLocaleString()
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.title + 4
              font.bold: true
            }

            Text {
              text: "RPM"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(3)
            }

            // Duty Cycle % Badge
            Rectangle {
              height: Style.space(20)
              width: dutyText.implicitWidth + Style.space(12)
              radius: 4
              color: (root.fanService && root.fanService.maxTestMode)
                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
              border.width: 1
              border.color: (root.fanService && root.fanService.maxTestMode) ? Color.accent : "transparent"
              anchors.verticalCenter: parent.verticalCenter

              Text {
                id: dutyText
                text: root.calculatedPercent + "% PWM"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                anchors.centerIn: parent
              }
            }
          }

          // Metadata Chips (CPU Temp, Max Rating, Noise dBA)
          Row {
            spacing: Style.space(10)

            Text {
              text: "🔥 " + root.currentTemp + "°C Package"
              color: Qt.darker(root.foregroundColor, 1.3)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }

            Text {
              text: "•"
              color: Qt.darker(root.foregroundColor, 2.2)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }

            Text {
              text: "󰓃 ~" + (root.fanService ? root.fanService.acousticDba : 24) + " dBA"
              color: Qt.darker(root.foregroundColor, 1.3)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }

            Text {
              text: "•"
              color: Qt.darker(root.foregroundColor, 2.2)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }

            Text {
              text: "Max: 5,800 RPM"
              color: Qt.darker(root.foregroundColor, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
          }
        }

        // Hero "⚡ Max RPM Test" Action Button
        Rectangle {
          width: Style.space(120)
          height: Style.space(42)
          radius: Style.cornerRadius - 2
          color: (root.fanService && root.fanService.maxTestMode)
            ? Color.accent
            : (testMouse.containsMouse ? Style.hoverFillFor(root.foregroundColor, Color.accent) : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.08))
          border.width: 1
          border.color: (root.fanService && root.fanService.maxTestMode) ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)

          Behavior on color { ColorAnimation { duration: 150 } }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: (root.fanService && root.fanService.maxTestMode) ? "󰓅" : "⚡"
              color: (root.fanService && root.fanService.maxTestMode) ? "#111111" : Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption + 1
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: (root.fanService && root.fanService.maxTestMode) ? "MAX ACTIVE" : "MAX TEST"
              color: (root.fanService && root.fanService.maxTestMode) ? "#111111" : root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          MouseArea {
            id: testMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.fanService) root.fanService.toggleMaxTest()
          }
        }
      }
    }

    // Temperature Curve Visualizer (Canvas Graph)
    Rectangle {
      id: curveCard
      width: parent.width
      height: Style.space(155)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(6)

        // Curve Header & Active Profile Chip
        RowLayout {
          width: parent.width

          Row {
            spacing: Style.space(6)
            Text {
              text: "󰈐 Fan Speed vs Temperature Curve"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            height: Style.space(20)
            width: profileLabel.implicitWidth + Style.space(12)
            radius: 4
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)

            Text {
              id: profileLabel
              text: "Profile: " + (root.fanService ? root.fanService.profile.toUpperCase() : "BALANCED")
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
              anchors.centerIn: parent
            }
          }
        }

        // Curve Canvas Graph
        Item {
          id: graphArea
          width: parent.width
          height: Style.space(110)

          Canvas {
            id: curveCanvas
            anchors.fill: parent

            Connections {
              target: root.fanService
              function onCurveChanged() { curveCanvas.requestPaint() }
              function onProfileChanged() { curveCanvas.requestPaint() }
            }

            Connections {
              target: root.hardwareStats
              function onCpuTempChanged() { curveCanvas.requestPaint() }
            }

            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()

              var w = width
              var h = height - 16
              var leftPad = 28
              var rightPad = 12
              var topPad = 6
              var bottomPad = h - 6
              var graphW = w - leftPad - rightPad
              var graphH = bottomPad - topPad

              // Draw horizontal grid lines (0%, 25%, 50%, 75%, 100%)
              ctx.strokeStyle = "rgba(255, 255, 255, 0.07)"
              ctx.lineWidth = 1
              ctx.fillStyle = "rgba(255, 255, 255, 0.4)"
              ctx.font = "9px sans-serif"

              for (var g = 0; g <= 4; g++) {
                var gy = bottomPad - (g / 4.0) * graphH
                ctx.beginPath()
                ctx.moveTo(leftPad, gy)
                ctx.lineTo(w - rightPad, gy)
                ctx.stroke()
                ctx.fillText((g * 25) + "%", 2, gy + 3)
              }

              // Temperature bounds: 30°C to 100°C
              var minT = 30.0
              var maxT = 100.0

              function getX(temp) {
                return leftPad + ((temp - minT) / (maxT - minT)) * graphW
              }

              function getY(speed) {
                return bottomPad - (speed / 100.0) * graphH
              }

              var pts = root.fanService ? root.fanService.curve : []
              if (!pts || pts.length < 2) return

              // 1. Draw Fill Area Under Curve
              var grad = ctx.createLinearGradient(0, topPad, 0, bottomPad)
              grad.addColorStop(0, "rgba(76, 175, 80, 0.30)")
              grad.addColorStop(1, "rgba(76, 175, 80, 0.00)")

              ctx.fillStyle = grad
              ctx.beginPath()
              ctx.moveTo(getX(pts[0].temp), bottomPad)
              for (var i = 0; i < pts.length; i++) {
                ctx.lineTo(getX(pts[i].temp), getY(pts[i].speed))
              }
              ctx.lineTo(getX(pts[pts.length - 1].temp), bottomPad)
              ctx.closePath()
              ctx.fill()

              // 2. Draw Main Curve Line
              ctx.strokeStyle = "#4CAF50"
              ctx.lineWidth = 2.5
              ctx.beginPath()
              ctx.moveTo(getX(pts[0].temp), getY(pts[0].speed))
              for (var j = 1; j < pts.length; j++) {
                ctx.lineTo(getX(pts[j].temp), getY(pts[j].speed))
              }
              ctx.stroke()

              // 3. Draw Live Operating Point Marker (Current CPU Temp)
              var curT = root.currentTemp
              var curS = root.calculatedPercent
              var curX = getX(curT)
              var curY = getY(curS)

              if (curT >= minT && curT <= maxT) {
                ctx.strokeStyle = "rgba(255, 193, 7, 0.5)"
                ctx.lineWidth = 1
                ctx.setLineDash([3, 3])
                ctx.beginPath()
                ctx.moveTo(curX, topPad)
                ctx.lineTo(curX, bottomPad)
                ctx.stroke()
                ctx.setLineDash([])

                // Glowing pulsing marker
                ctx.fillStyle = "#FFC107"
                ctx.beginPath()
                ctx.arc(curX, curY, 5, 0, 2 * Math.PI)
                ctx.fill()

                ctx.strokeStyle = "#ffffff"
                ctx.lineWidth = 1.5
                ctx.stroke()
              }

              // 4. Draw Interactive Control Point Nodes
              for (var k = 0; k < pts.length; k++) {
                var px = getX(pts[k].temp)
                var py = getY(pts[k].speed)
                var isSel = (root.selectedPointIndex === k)

                ctx.fillStyle = isSel ? "#4CAF50" : "rgba(76, 175, 80, 0.8)"
                ctx.beginPath()
                ctx.arc(px, py, isSel ? 6 : 4, 0, 2 * Math.PI)
                ctx.fill()

                if (isSel) {
                  ctx.strokeStyle = "#ffffff"
                  ctx.lineWidth = 2
                  ctx.stroke()
                }

                // Temp labels at bottom
                ctx.fillStyle = isSel ? "#4CAF50" : "rgba(255, 255, 255, 0.5)"
                ctx.font = isSel ? "bold 9px sans-serif" : "9px sans-serif"
                ctx.fillText(pts[k].temp + "°", px - 8, h + 12)
              }
            }
          }

          // Click handler to select curve point
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              var w = width
              var leftPad = 28
              var rightPad = 12
              var graphW = w - leftPad - rightPad
              var minT = 30.0
              var maxT = 100.0

              var pts = root.fanService ? root.fanService.curve : []
              if (!pts) return
              var closestIdx = 0
              var closestDist = 999999

              for (var i = 0; i < pts.length; i++) {
                var px = leftPad + ((pts[i].temp - minT) / (maxT - minT)) * graphW
                var d = Math.abs(mouse.x - px)
                if (d < closestDist) {
                  closestDist = d
                  closestIdx = i
                }
              }
              root.selectedPointIndex = closestIdx
              curveCanvas.requestPaint()
            }
          }
        }
      }
    }

    // Presets Row + Point Fine-Tuning Stepper Matrix
    RowLayout {
      width: parent.width
      spacing: Style.space(10)

      // 4 Preset Buttons Container
      Rectangle {
        Layout.fillWidth: true
        height: Style.space(65)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          Text {
            text: "Cooling Presets"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(6)

            // Silent Preset
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(26)
              radius: 4
              color: (root.fanService && root.fanService.profile === "silent")
                ? Color.accent
                : (p1Mouse.containsMouse ? Style.hoverFillFor(root.foregroundColor, Color.accent) : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.08))
              border.width: 1
              border.color: (root.fanService && root.fanService.profile === "silent") ? Color.accent : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)

              Text {
                text: "🍃 Silent"
                color: (root.fanService && root.fanService.profile === "silent") ? "#111111" : root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                anchors.centerIn: parent
              }
              MouseArea {
                id: p1Mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.fanService) root.fanService.applyPreset("silent")
              }
            }

            // Balanced Preset
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(26)
              radius: 4
              color: (root.fanService && root.fanService.profile === "balanced")
                ? Color.accent
                : (p2Mouse.containsMouse ? Style.hoverFillFor(root.foregroundColor, Color.accent) : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.08))
              border.width: 1
              border.color: (root.fanService && root.fanService.profile === "balanced") ? Color.accent : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)

              Text {
                text: "⚖️ Balanced"
                color: (root.fanService && root.fanService.profile === "balanced") ? "#111111" : root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                anchors.centerIn: parent
              }
              MouseArea {
                id: p2Mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.fanService) root.fanService.applyPreset("balanced")
              }
            }

            // Performance Preset
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(26)
              radius: 4
              color: (root.fanService && root.fanService.profile === "performance")
                ? Color.accent
                : (p3Mouse.containsMouse ? Style.hoverFillFor(root.foregroundColor, Color.accent) : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.08))
              border.width: 1
              border.color: (root.fanService && root.fanService.profile === "performance") ? Color.accent : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)

              Text {
                text: "🚀 Turbo"
                color: (root.fanService && root.fanService.profile === "performance") ? "#111111" : root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                anchors.centerIn: parent
              }
              MouseArea {
                id: p3Mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.fanService) root.fanService.applyPreset("performance")
              }
            }
          }
        }
      }

      // Point Fine-Tuning Slider/Stepper Card
      Rectangle {
        width: Style.space(215)
        height: Style.space(65)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          RowLayout {
            width: parent.width

            Text {
              text: "Point " + (root.selectedPointIndex + 1) + " (" + root.currentPoint.temp + "°C)"
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.currentPoint.speed + "% Fan"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              font.bold: true
            }
          }

          // Stepper Buttons & Slider
          RowLayout {
            width: parent.width
            spacing: Style.space(6)

            // - 5% Button
            Rectangle {
              width: Style.space(26)
              height: Style.space(24)
              radius: 4
              color: mMinus.containsMouse ? Style.hoverFillFor(root.foregroundColor, Color.accent) : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.08)
              border.width: 1
              border.color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)

              Text {
                text: "−"
                color: root.foregroundColor
                font.bold: true
                anchors.centerIn: parent
              }
              MouseArea {
                id: mMinus
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.fanService) root.fanService.updatePointSpeed(root.selectedPointIndex, root.currentPoint.speed - 5)
              }
            }

            // Interactive Mini Slider Bar
            Rectangle {
              id: pointSliderTrack
              Layout.fillWidth: true
              height: Style.space(8)
              radius: 4
              color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.15)
              clip: true

              Rectangle {
                width: parent.width * (root.currentPoint.speed / 100.0)
                height: parent.height
                radius: 4
                color: Color.accent
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                  var spd = Math.max(0, Math.min(100, Math.round((mouse.x / pointSliderTrack.width) * 100)))
                  if (root.fanService) root.fanService.updatePointSpeed(root.selectedPointIndex, spd)
                }
                onPositionChanged: function(mouse) {
                  if (pressed) {
                    var spd = Math.max(0, Math.min(100, Math.round((mouse.x / pointSliderTrack.width) * 100)))
                    if (root.fanService) root.fanService.updatePointSpeed(root.selectedPointIndex, spd)
                  }
                }
              }
            }

            // + 5% Button
            Rectangle {
              width: Style.space(26)
              height: Style.space(24)
              radius: 4
              color: mPlus.containsMouse ? Style.hoverFillFor(root.foregroundColor, Color.accent) : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.08)
              border.width: 1
              border.color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)

              Text {
                text: "+"
                color: root.foregroundColor
                font.bold: true
                anchors.centerIn: parent
              }
              MouseArea {
                id: mPlus
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.fanService) root.fanService.updatePointSpeed(root.selectedPointIndex, root.currentPoint.speed + 5)
              }
            }
          }
        }
      }
    }
  }
}
