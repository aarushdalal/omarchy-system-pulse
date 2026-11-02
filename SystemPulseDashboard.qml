import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as OmarchyPalette
import qs.Ui
import "components/polish" as Polish
import "cards"
import "services"

Polish.RefinedPopupCard {
  id: root

  property var mediaService: null
  property var visualizerService: null
  property int activeTabIndex: 0 // 0: Storage, 1: Compute, 2: Audio, 3: Deck, 4: Weather, 5: Fan
  property bool anchorHovered: false
  readonly property bool dashboardMotionEnabled: root.open && !Polish.MotionAdapter.reducedMotion
  readonly property string dashboardUiRevision: "premium-ui-20261102"
  onActiveTabIndexChanged: {
    var bounded = Math.max(0, Math.min(5, activeTabIndex))
    if (bounded !== activeTabIndex) activeTabIndex = bounded
    if (pageViewport) pageViewport.contentY = 0
  }

  contentWidth: Style.space(560)
  contentHeight: root.cappedContentHeight(Style.space(438))
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
      if (root.triggerMode === "hover" && root.open && !root.containsMouse && !root.anchorHovered) {
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
    if (!root.open) return
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
      if (pageViewport.overflow && Math.abs(wheel.angleDelta.y) > Math.abs(wheel.angleDelta.x)) {
        wheel.accepted = false
        return
      }
      root.handleWheel(wheel)
    }
  }

  // Main UI Canvas
  Item {
    id: mainCanvas
    anchors.fill: parent

    Polish.DashboardTabs {
      id: tabSwitcher
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      height: implicitHeight
      title: "System Pulse"
      currentIndex: root.activeTabIndex
      foregroundColor: root.bar ? root.bar.barForeground : OmarchyPalette.Color.foreground
      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      motionEnabled: root.dashboardMotionEnabled
      enabled: root.open
      onSelectionRequested: function(index) { root.activeTabIndex = index }
    }

    // Short spatial reveals retain direction without moving several panel widths.
    Flickable {
      id: pageViewport
      objectName: "dashboard-page-viewport"
      readonly property bool overflow: contentHeight > height + 1
      activeFocusOnTab: overflow
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: width
      contentHeight: carouselStack.height
      Keys.onPressed: function(event) {
        if (!overflow) return
        var next = contentY
        if (event.key === Qt.Key_PageDown) next += height * .8
        else if (event.key === Qt.Key_PageUp) next -= height * .8
        else if (event.key === Qt.Key_Home) next = 0
        else if (event.key === Qt.Key_End) next = contentHeight - height
        else return
        contentY = Math.max(0, Math.min(contentHeight - height, next))
        event.accepted = true
      }
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: tabSwitcher.bottom
      anchors.bottom: parent.bottom
      anchors.topMargin: Style.space(8)
      clip: true

      Item {
        id: carouselStack
        width: pageViewport.width
        readonly property var activePage: [page0, page1, page2, page3, page4, page5][root.activeTabIndex]
        height: Math.max(pageViewport.height, activePage ? activePage.preferredHeight : 0)

      // Card 0: Storage
      Polish.DashboardPage {
        width: carouselStack.width
        height: carouselStack.height
        id: page0
        objectName: "dashboard-page-0"
        pageIndex: 0
        selectedIndex: root.activeTabIndex
        travel: Style.space(Polish.MotionAdapter.dashboardTravel)
        motionEnabled: root.dashboardMotionEnabled
        enabled: root.open && selected
        StorageCard {
          anchors.fill: parent
          hardwareStats: hwStats
          foregroundColor: root.bar ? root.bar.barForeground : OmarchyPalette.Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 1: Compute
      Polish.DashboardPage {
        width: carouselStack.width
        height: carouselStack.height
        id: page1
        objectName: "dashboard-page-1"
        pageIndex: 1
        selectedIndex: root.activeTabIndex
        travel: Style.space(Polish.MotionAdapter.dashboardTravel)
        motionEnabled: root.dashboardMotionEnabled
        enabled: root.open && selected
        ComputeCard {
          anchors.fill: parent
          hardwareStats: hwStats
          foregroundColor: root.bar ? root.bar.barForeground : OmarchyPalette.Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 2: Audio Studio & Hero Poster
      Polish.DashboardPage {
        width: carouselStack.width
        height: carouselStack.height
        id: page2
        objectName: "dashboard-page-2"
        pageIndex: 2
        selectedIndex: root.activeTabIndex
        travel: Style.space(Polish.MotionAdapter.dashboardTravel)
        motionEnabled: root.dashboardMotionEnabled
        enabled: root.open && selected
        AudioCard {
          anchors.fill: parent
          mediaService: root.mediaService
          visualizerService: root.visualizerService
          foregroundColor: root.bar ? root.bar.barForeground : OmarchyPalette.Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 3: Deck & Calendar
      Polish.DashboardPage {
        width: carouselStack.width
        height: carouselStack.height
        id: page3
        objectName: "dashboard-page-3"
        pageIndex: 3
        selectedIndex: root.activeTabIndex
        travel: Style.space(Polish.MotionAdapter.dashboardTravel)
        motionEnabled: root.dashboardMotionEnabled
        enabled: root.open && selected
        DeckCard {
          anchors.fill: parent
          bar: root.bar
          foregroundColor: root.bar ? root.bar.barForeground : OmarchyPalette.Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 4: Weather Hub
      Polish.DashboardPage {
        width: carouselStack.width
        height: carouselStack.height
        id: page4
        objectName: "dashboard-page-4"
        pageIndex: 4
        selectedIndex: root.activeTabIndex
        travel: Style.space(Polish.MotionAdapter.dashboardTravel)
        motionEnabled: root.dashboardMotionEnabled
        enabled: root.open && selected
        WeatherCard {
          anchors.fill: parent
          foregroundColor: root.bar ? root.bar.barForeground : OmarchyPalette.Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      // Card 5: Fan Control & Thermal Curve Hub
      Polish.DashboardPage {
        width: carouselStack.width
        height: carouselStack.height
        id: page5
        objectName: "dashboard-page-5"
        pageIndex: 5
        selectedIndex: root.activeTabIndex
        travel: Style.space(Polish.MotionAdapter.dashboardTravel)
        motionEnabled: root.dashboardMotionEnabled
        enabled: root.open && selected
        FanCard {
          anchors.fill: parent
          hardwareStats: hwStats
          fanService: fanService
          foregroundColor: root.bar ? root.bar.barForeground : OmarchyPalette.Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }
      }
      Rectangle {
        parent: pageViewport
        visible: pageViewport.overflow
        width: 3
        height: Math.max(18, pageViewport.height * pageViewport.height / Math.max(1, pageViewport.contentHeight))
        x: pageViewport.width - width
        y: (pageViewport.height - height) * pageViewport.contentY / Math.max(1, pageViewport.contentHeight - pageViewport.height)
        radius: 1.5
        color: Qt.rgba(OmarchyPalette.Color.foreground.r, OmarchyPalette.Color.foreground.g, OmarchyPalette.Color.foreground.b, .28)
      }
    }
  }
}
