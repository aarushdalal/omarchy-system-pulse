import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  required property QtObject bar
  required property color foregroundColor
  required property string fontFamily

  property date viewDate: new Date()
  readonly property date today: new Date()

  readonly property int currentYear: viewDate.getFullYear()
  readonly property int currentMonth: viewDate.getMonth()
  readonly property string monthName: Qt.formatDateTime(viewDate, "MMMM yyyy")

  // Calendar matrix calculations
  readonly property var calendarModel: {
    var firstDay = new Date(currentYear, currentMonth, 1)
    var startingDayOfWeek = (firstDay.getDay() + 6) % 7 // Monday = 0
    var daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
    var daysInPrevMonth = new Date(currentYear, currentMonth, 0).getDate()

    var cells = []
    for (var i = 0; i < 42; i++) {
      var dayNum = 0
      var isCurMonth = false
      var isTodayCell = false

      if (i < startingDayOfWeek) {
        dayNum = daysInPrevMonth - startingDayOfWeek + i + 1
        isCurMonth = false
      } else if (i >= startingDayOfWeek + daysInMonth) {
        dayNum = i - (startingDayOfWeek + daysInMonth) + 1
        isCurMonth = false
      } else {
        dayNum = i - startingDayOfWeek + 1
        isCurMonth = true
        if (dayNum === today.getDate() && currentMonth === today.getMonth() && currentYear === today.getFullYear()) {
          isTodayCell = true
        }
      }

      cells.push({
        day: dayNum,
        isCurrentMonth: isCurMonth,
        isToday: isTodayCell
      })
    }
    return cells
  }

  function prevMonth() {
    root.viewDate = new Date(root.currentYear, root.currentMonth - 1, 1)
  }

  function nextMonth() {
    root.viewDate = new Date(root.currentYear, root.currentMonth + 1, 1)
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

    // Header Row with Title and Month Controls
    RowLayout {
      width: parent.width

      Row {
        spacing: Style.space(8)
        Text {
          text: "󰸗"
          color: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "Calendar Deck"
          color: root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Item { Layout.fillWidth: true }

      // Month Switcher Controls
      Row {
        spacing: Style.space(6)
        Layout.alignment: Qt.AlignVCenter

        Button {
          iconText: "󰅁"
          foreground: root.foregroundColor
          fontFamily: root.fontFamily
          onClicked: root.prevMonth()
        }

        Text {
          text: root.monthName
          color: root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }

        Button {
          iconText: "󰅂"
          foreground: root.foregroundColor
          fontFamily: root.fontFamily
          onClicked: root.nextMonth()
        }
      }
    }

    // Full Interactive Month Calendar Grid (Frameless Glass Surface)
    Rectangle {
      width: parent.width
      height: calCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      Column {
        id: calCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(10)
        spacing: Style.space(4)

        // Day-of-week header row
        Row {
          width: parent.width
          spacing: 0
          Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Item {
              width: parent.width / 7
              height: Style.space(18)
              Text {
                anchors.centerIn: parent
                text: modelData
                color: Qt.darker(root.foregroundColor, 1.6)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        // Calendar Day Cells (6 rows x 7 days = 42 cells)
        Grid {
          width: parent.width
          columns: 7
          rowSpacing: Style.space(3)
          columnSpacing: 0

          Repeater {
            model: root.calendarModel

            Rectangle {
              required property var modelData
              width: parent.width / 7
              height: Style.space(24)
              radius: Style.cornerRadius
              color: modelData.isToday ? Color.accent : "transparent"

              Text {
                anchors.centerIn: parent
                text: modelData.day
                color: modelData.isToday
                  ? Color.background
                  : (modelData.isCurrentMonth ? root.foregroundColor : Qt.darker(root.foregroundColor, 2.2))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: modelData.isToday
              }
            }
          }
        }
      }
    }
  }
}
