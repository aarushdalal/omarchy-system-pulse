import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "cards"
import "services"

PopupCard {
  id: root

  property var mediaService: null
  property var visualizerService: null
  property int activeTabIndex: 0 // 0: Storage, 1: Compute, 2: Audio, 3: Deck, 4: Weather, 5: Fan
  property bool anchorHovered: false

  contentWidth: Style.space(560)
  contentHeight: Style.space(430)
  borderSpec: Border.none()
  triggerMode: "click"

  function show() { root.open = true }
  function hide() { root.close() }
  function toggle() { root.open ? root.close() : (root.open = true) }

  // Auto-collapse when cursor leaves the dashboard and the anchor pill
  property Timer leaveCollapseTimer: Timer {
    id: leaveCollapseTimer
    interval: 220
    running: false
    repeat: false
    onTriggered: {
      if (root.open && !root.containsMouse && !root.anchorHovered) {
        root.close()
      }
    }
  }

  onContainsMouseChanged: {
    if (root.open) {
      if (!root.containsMouse && !root.anchorHovered) {
        leaveCollapseTimer.restart()
      } else {
        leaveCollapseTimer.stop()
      }
    }
  }

  onAnchorHoveredChanged: {
    if (root.open) {
      if (!root.containsMouse && !root.anchorHovered) {
        leaveCollapseTimer.restart()
      } else {
        leaveCollapseTimer.stop()
      }
    }
  }

  // Hardware Telemetry Service (Only active when open)
  HardwareStats {
    id: hwStats
    active: root.open
  }

  // Fan Control & Thermal Curve Service
  FanService {
    id: fanService
    hardwareStats: hwStats
  }

  // High-Precision Trackpad & Mouse Wheel Navigator across 6 tabs
  property real wheelAccumulator: 0
  property real lastWheelEventTime: 0
  property real lastTriggerTime: 0
  readonly property real wheelThreshold: 20

  function handleWheel(wheelOrDelta) {
    var now = Date.now()
    var dy = 0
    var dx = 0

    if (typeof wheelOrDelta === "number") {
      dy = wheelOrDelta
    } else if (wheelOrDelta && typeof wheelOrDelta === "object") {
      if (wheelOrDelta.angleDelta) {
        dy = wheelOrDelta.angleDelta.y || 0
        dx = wheelOrDelta.angleDelta.x || 0
      }
      if (dy === 0 && dx === 0 && wheelOrDelta.pixelDelta) {
        dy = (wheelOrDelta.pixelDelta.y || 0) * 4
        dx = (wheelOrDelta.pixelDelta.x || 0) * 4
      }
    }

    if (dy === 0 && dx === 0) return

    // Reset accumulator on finger lift / pause (> 220ms)
    if (now - lastWheelEventTime > 220) {
      wheelAccumulator = 0
    }
    lastWheelEventTime = now

    // Cooldown prevents momentum fling from skipping multiple tabs
    if (now - lastTriggerTime < 240) {
      return
    }

    var dominant = Math.abs(dx) > Math.abs(dy) ? dx : dy
    wheelAccumulator += dominant

    if (wheelAccumulator >= wheelThreshold) {
      wheelAccumulator = 0
      lastTriggerTime = now
      root.activeTabIndex = (root.activeTabIndex - 1 + 6) % 6
    } else if (wheelAccumulator <= -wheelThreshold) {
      wheelAccumulator = 0
      lastTriggerTime = now
      root.activeTabIndex = (root.activeTabIndex + 1) % 6
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: function(wheel) {
      root.handleWheel(wheel)
    }
  }

  // Main UI Canvas
  Item {
    id: mainCanvas
    anchors.fill: parent

    // Top Segmented Tab Switcher with Gliding Pill Indicator
    Rectangle {
      id: tabSwitcher
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: Style.space(40)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.bar ? root.bar.barForeground : Color.foreground, Color.accent)

      readonly property var tabs: [
        { icon: "󰋊", label: "Storage", index: 0 },
        { icon: "󰍛", label: "Compute", index: 1 },
        { icon: "󰝚", label: "Audio", index: 2 },
        { icon: "󰸗", label: "Deck", index: 3 },
        { icon: "🌤️", label: "Weather", index: 4 },
        { icon: "󰈐", label: "Fan", index: 5 }
      ]

      readonly property real singleTabWidth: (tabSwitcher.width - Style.space(6) - (tabSwitcher.tabs.length - 1) * Style.space(4)) / tabSwitcher.tabs.length

      // Smooth Sliding Active Pill Indicator with subtle Jade underline
      Rectangle {
        id: activePill
        y: Style.space(3)
        height: tabSwitcher.height - Style.space(6)
        width: tabSwitcher.singleTabWidth
        x: Style.space(3) + root.activeTabIndex * (tabSwitcher.singleTabWidth + Style.space(4))
        radius: Style.cornerRadius - 2
        color: Style.selectedFillFor(root.bar ? root.bar.barForeground : Color.foreground, Color.accent)
        border.width: 1
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.40)

        // Kinetic bottom accent glide bar
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(1)
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.round(parent.width * 0.55)
          height: 2
          radius: 1
          color: Color.accent
          opacity: 0.95
        }

        Behavior on x {
          NumberAnimation { duration: Motion.liquidMoveDuration; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot }
        }
      }

      Row {
        id: tabsRow
        anchors.fill: parent
        anchors.margins: Style.space(3)
        spacing: Style.space(4)

        Repeater {
          model: tabSwitcher.tabs

          Item {
            id: tabItem
            width: tabSwitcher.singleTabWidth
            height: tabsRow.height
            readonly property bool isSelected: root.activeTabIndex === modelData.index
            scale: tabMouse.pressed ? Motion.pressScale : 1.0

            Behavior on scale {
              NumberAnimation { duration: Motion.micro; easing.type: Motion.easeStandard }
            }

            Rectangle {
              anchors.fill: parent
              radius: Style.cornerRadius - 2
              color: tabMouse.containsMouse && !tabItem.isSelected
                ? Style.hoverFillFor(root.bar ? root.bar.barForeground : Color.foreground, Color.accent)
                : "transparent"

              Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeStandard } }

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text {
                  id: iconText
                  text: modelData.icon
                  color: tabItem.isSelected ? Color.accent : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption + 1
                  anchors.verticalCenter: parent.verticalCenter
                  scale: tabItem.isSelected ? (1.0 + 0.15 * Motion.springOvershoot) : (tabMouse.containsMouse ? (1.0 + 0.06 * Motion.springOvershoot) : 1.0)

                  Behavior on scale {
                    NumberAnimation { duration: Motion.micro; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot }
                  }
                  Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeStandard } }
                }

                Text {
                  id: labelText
                  text: modelData.label
                  color: tabItem.isSelected ? Color.accent : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.4)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: tabItem.isSelected
                  anchors.verticalCenter: parent.verticalCenter

                  Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeStandard } }
                }
              }
            }

            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTabIndex = modelData.index
              onWheel: function(wheel) {
                root.handleWheel(wheel)
              }
            }
          }
        }
      }
    }

    // Horizontal Sliding Carousel Stack with Depth Perspective
    Item {
      id: carouselStack
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: tabSwitcher.bottom
      anchors.bottom: parent.bottom
      anchors.topMargin: Style.space(8)
      clip: true

      // Card 0: Storage
      Item {
        width: carouselStack.width
        height: carouselStack.height
        x: (0 - root.activeTabIndex) * carouselStack.width
        scale: root.activeTabIndex === 0 ? 1.0 : 0.94
        opacity: Math.max(0.0, 1.0 - Math.abs(0 - root.activeTabIndex) * 0.8)
        visible: Math.abs(0 - root.activeTabIndex) <= 1

        Behavior on x { NumberAnimation { duration: Motion.entryDuration; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        StorageCard {
          anchors.fill: parent
          hardwareStats: hwStats
          foregroundColor: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 1: Compute
      Item {
        width: carouselStack.width
        height: carouselStack.height
        x: (1 - root.activeTabIndex) * carouselStack.width
        scale: root.activeTabIndex === 1 ? 1.0 : 0.94
        opacity: Math.max(0.0, 1.0 - Math.abs(1 - root.activeTabIndex) * 0.8)
        visible: Math.abs(1 - root.activeTabIndex) <= 1

        Behavior on x { NumberAnimation { duration: Motion.entryDuration; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        ComputeCard {
          anchors.fill: parent
          hardwareStats: hwStats
          foregroundColor: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 2: Audio Studio & Hero Poster
      Item {
        width: carouselStack.width
        height: carouselStack.height
        x: (2 - root.activeTabIndex) * carouselStack.width
        scale: root.activeTabIndex === 2 ? 1.0 : 0.94
        opacity: Math.max(0.0, 1.0 - Math.abs(2 - root.activeTabIndex) * 0.8)
        visible: Math.abs(2 - root.activeTabIndex) <= 1

        Behavior on x { NumberAnimation { duration: Motion.entryDuration; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        AudioCard {
          anchors.fill: parent
          mediaService: root.mediaService
          visualizerService: root.visualizerService
          foregroundColor: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 3: Deck & Calendar
      Item {
        width: carouselStack.width
        height: carouselStack.height
        x: (3 - root.activeTabIndex) * carouselStack.width
        scale: root.activeTabIndex === 3 ? 1.0 : 0.94
        opacity: Math.max(0.0, 1.0 - Math.abs(3 - root.activeTabIndex) * 0.8)
        visible: Math.abs(3 - root.activeTabIndex) <= 1

        Behavior on x { NumberAnimation { duration: Motion.entryDuration; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        DeckCard {
          anchors.fill: parent
          bar: root.bar
          foregroundColor: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 4: Weather Hub
      Item {
        width: carouselStack.width
        height: carouselStack.height
        x: (4 - root.activeTabIndex) * carouselStack.width
        scale: root.activeTabIndex === 4 ? 1.0 : 0.94
        opacity: Math.max(0.0, 1.0 - Math.abs(4 - root.activeTabIndex) * 0.8)
        visible: Math.abs(4 - root.activeTabIndex) <= 1

        Behavior on x { NumberAnimation { duration: Motion.entryDuration; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        WeatherCard {
          anchors.fill: parent
          foregroundColor: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 5: Fan Control & Thermal Curve Hub
      Item {
        width: carouselStack.width
        height: carouselStack.height
        x: (5 - root.activeTabIndex) * carouselStack.width
        scale: root.activeTabIndex === 5 ? 1.0 : 0.94
        opacity: Math.max(0.0, 1.0 - Math.abs(5 - root.activeTabIndex) * 0.8)
        visible: Math.abs(5 - root.activeTabIndex) <= 1

        Behavior on x { NumberAnimation { duration: Motion.entryDuration; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        FanCard {
          anchors.fill: parent
          hardwareStats: hwStats
          fanService: fanService
          foregroundColor: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }
    }
  }
}
