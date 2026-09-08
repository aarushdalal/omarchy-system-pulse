import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "services"

BarWidget {
  id: root
  moduleName: "daemon0.system-pulse"

  IpcHandler {
    target: "daemon0.system-pulse"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  property date currentDate: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      root.currentDate = new Date()
      syncStateView.reload()
      focusStateView.reload()
    }
  }

  // Live Hardware Telemetry Monitor (CPU, RAM, GPU, thermals)
  HardwareStats {
    id: hwStats
    active: true
  }

  // ==========================================================================
  // REAL-TIME EVENT BUS (CLOUD SYNC & STUDY FOCUS MONITORING)
  // ==========================================================================
  readonly property string syncStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))) + "/omarchy-cloud-sync/state.json"
  property bool isSyncing: false
  property string syncSpeed: "0 B/s"
  property real syncPct: 0.0

  FileView {
    id: syncStateView
    path: root.syncStatePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var raw = text()
      if (!raw || raw.trim() === "") return
      try {
        var d = JSON.parse(raw.trim())
        root.isSyncing = (d.active === true)
        root.syncSpeed = d.speed || "0 B/s"
        root.syncPct = (typeof d.progress_pct === "number") ? d.progress_pct : 0.0
      } catch(e) {}
    }
  }

  readonly property string focusStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-study-mode/state.json"
  property bool isStudying: false
  property int studyRemainingSecs: 0

  FileView {
    id: focusStateView
    path: root.focusStatePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var raw = text()
      if (!raw || raw.trim() === "") return
      try {
        var d = JSON.parse(raw.trim())
        root.isStudying = (d.active === true)
        root.studyRemainingSecs = d.remaining_seconds || 0
      } catch(e) {}
    }
  }

  // ==========================================================================
  // MEDIA PLAYBACK MONITORS
  // ==========================================================================
  function isWallpaperOrDummy(p) {
    if (!p) return true;
    var name = String(p.identity || p.desktopEntry || p.dbusName || "").toLowerCase();
    var track = String(p.trackTitle || "").toLowerCase();
    if (name.indexOf("mpvpaper") !== -1 || name.indexOf("paper") !== -1) return true;
    if (name.indexOf("mpv") !== -1 && (track.indexOf(".mp4") !== -1 || track.indexOf(".mkv") !== -1 || track.indexOf(".webm") !== -1 || track === "")) {
      return true;
    }
    return false;
  }

  // Active Media Player detection (Strictly music/video players, ignoring wallpapers)
  readonly property var activePlayer: {
    if (Mpris.players && Mpris.players.values.length > 0) {
      for (var i = 0; i < Mpris.players.values.length; i++) {
        var p = Mpris.players.values[i];
        if (p && !isWallpaperOrDummy(p) && p.isPlaying) return p;
      }
      for (var j = 0; j < Mpris.players.values.length; j++) {
        var p2 = Mpris.players.values[j];
        if (p2 && !isWallpaperOrDummy(p2)) return p2;
      }
    }
    return null;
  }

  readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying === true : false
  readonly property string trackTitle: activePlayer && activePlayer.trackTitle ? activePlayer.trackTitle : ""
  readonly property string trackArtist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : ""
  readonly property string trackArtUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""

  function togglePlayPause() {
    if (!root.activePlayer || root.isWallpaperOrDummy(root.activePlayer)) return
    if (root.activePlayer.canTogglePlaying && typeof root.activePlayer.togglePlaying === "function") {
      root.activePlayer.togglePlaying()
    } else if (root.activePlayer.isPlaying && root.activePlayer.canPause && typeof root.activePlayer.pause === "function") {
      root.activePlayer.pause()
    } else if (!root.activePlayer.isPlaying && root.activePlayer.canPlay && typeof root.activePlayer.play === "function") {
      root.activePlayer.play()
    } else if (typeof root.activePlayer.togglePlaying === "function") {
      root.activePlayer.togglePlaying()
    }
  }

  function nextTrack() {
    if (root.activePlayer && !root.isWallpaperOrDummy(root.activePlayer) && typeof root.activePlayer.next === "function") {
      root.activePlayer.next()
    }
  }

  function prevTrack() {
    if (root.activePlayer && !root.isWallpaperOrDummy(root.activePlayer) && typeof root.activePlayer.previous === "function") {
      root.activePlayer.previous()
    }
  }

  // Fingerprint Lockscreen Spacebar Wake Handler
  readonly property var lockService: (root.shell && typeof root.shell.serviceFor === "function") ? root.shell.serviceFor("omarchy.lock") : null

  Connections {
    target: root.lockService
    function onEnteredPasswordChanged() {
      if (!root.lockService) return;
      if (root.lockService.enteredPassword === " ") {
        root.lockService.enteredPassword = "";
        root.lockService.runWake();
        if (root.lockService.fingerprintConfigured && !root.lockService.authenticatingPassword) {
          if (root.lockService.fingerprintPam && root.lockService.fingerprintPam.active) {
            root.lockService.fingerprintPam.abort();
          }
          root.lockService.fingerprintAuthenticating = false;
          rearmTimer.restart();
        }
      }
    }
  }

  Timer {
    id: rearmTimer
    interval: 150
    repeat: false
    onTriggered: {
      if (root.lockService && root.lockService.locked && root.lockService.fingerprintConfigured) {
        root.lockService.startFingerprint();
      }
    }
  }

  // Real-Time PipeWire Audio Visualizer Engine (Only active when playing or dashboard open)
  AudioVisualizerService {
    id: audioViz
    active: root.isPlaying || dashboard.open
  }

  // Popup open/close shape contract for shell/bar
  readonly property bool opened: dashboard.open
  function open() { dashboard.open = true }
  function close() { dashboard.open = false }
  function toggle() { dashboard.open = !dashboard.open }

  implicitWidth: islandSurface.implicitWidth
  implicitHeight: root.barSize

  // The Taskbar Center "Bump" Island (Borderless, Scaled Up with Spring Morphing)
  BorderSurface {
    id: islandSurface
    anchors.centerIn: parent
    implicitWidth: rowLayout.implicitWidth + Style.space(24)
    height: Math.max(14, root.barSize - Style.space(2))
    radius: Style.cornerRadius
    color: islandMouse.containsMouse
      ? Style.hoverFillFor(root.bar ? root.bar.barForeground : Color.bar.text, Color.accent)
      : (root.opened ? Style.selectedFillFor(root.bar ? root.bar.barForeground : Color.bar.text, Color.accent) : Style.normalFillFor(root.bar ? root.bar.barForeground : Color.bar.text, Color.accent))
    borderSpec: Border.none()
    scale: islandMouse.pressed ? Motion.pressScale : (islandMouse.containsMouse ? (1.0 + 0.03 * Motion.springOvershoot) : 1.0)

    Behavior on implicitWidth { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    Behavior on scale { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeExpressive; easing.overshoot: Motion.springOvershoot } }
    Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeStandard } }

    Row {
      id: rowLayout
      anchors.centerIn: parent
      spacing: Style.space(8)

      // 1. Fixed Day & Time
      Row {
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: Qt.formatDateTime(root.currentDate, "ddd, d MMM").toUpperCase()
          color: Qt.darker(root.bar ? root.bar.barForeground : Color.bar.text, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "•"
          color: Qt.darker(root.bar ? root.bar.barForeground : Color.bar.text, 2.0)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: Qt.formatDateTime(root.currentDate, "HH:mm")
          color: root.bar ? root.bar.barForeground : Color.bar.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // 2. Vertical Divider
      Rectangle {
        width: 1
        height: Style.space(14)
        color: root.bar ? root.bar.barForeground : Color.bar.text
        opacity: 0.25
        anchors.verticalCenter: parent.verticalCenter
      }

      // 3. Live Hardware Telemetry Section (CPU & RAM)
      Row {
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          text: "󰍛"
          color: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: hwStats.cpuBusyPercent + "%"
          color: root.bar ? root.bar.barForeground : Color.bar.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "•"
          color: Qt.darker(root.bar ? root.bar.barForeground : Color.bar.text, 2.0)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "󰘚"
          color: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: hwStats.ramPercent + "%"
          color: root.bar ? root.bar.barForeground : Color.bar.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // 4. Vertical Divider
      Rectangle {
        width: 1
        height: Style.space(14)
        color: root.bar ? root.bar.barForeground : Color.bar.text
        opacity: 0.25
        anchors.verticalCenter: parent.verticalCenter
      }

      // 5. Audio / Playback Status Pill Section
      Row {
        spacing: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter

        // Large Rounded Square Album Poster in Collapsed Bar
        Rectangle {
          width: Math.max(14, root.barSize - Style.space(4))
          height: Math.max(14, root.barSize - Style.space(4))
          radius: 3
          color: Style.selectedFillFor(root.bar ? root.bar.barForeground : Color.bar.text, Color.accent)
          clip: true
          anchors.verticalCenter: parent.verticalCenter
          visible: root.isPlaying || audioViz.hasAudio || root.trackArtUrl !== ""

          Image {
            anchors.fill: parent
            source: root.trackArtUrl
            fillMode: Image.PreserveAspectCrop
            visible: root.trackArtUrl !== ""
          }

          Text {
            anchors.centerIn: parent
            text: "󰝚"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            visible: root.trackArtUrl === ""
          }
        }

        // Live Real Equalizer Wave (8 Bands: Sub-Bass to Treble Spectrum)
        Row {
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter
          visible: root.isPlaying || audioViz.hasAudio

          Repeater {
            model: [0, 2, 4, 6, 8, 10, 13, 16]

            Rectangle {
              required property int modelData
              required property int index
              width: 2.5
              property real level: (audioViz && audioViz.updateSeq >= 0 && audioViz.bars && audioViz.bars[modelData] !== undefined) ? audioViz.bars[modelData] : 0
              property real targetH: Math.max(3, Math.min(20, 3 + (level / 100.0) * 17))
              height: targetH
              color: Color.accent
              opacity: 0.85 + (index % 2) * 0.15
              radius: 1
              anchors.verticalCenter: parent.verticalCenter

              Behavior on height {
                NumberAnimation { duration: 20; easing.type: Easing.OutQuad }
              }
            }
          }
        }

        Text {
          text: (root.isPlaying || audioViz.hasAudio) ? "󰏤" : "󰐊"
          color: (root.isPlaying || audioViz.hasAudio) ? Color.accent : Qt.darker(root.bar ? root.bar.barForeground : Color.bar.text, 1.6)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          visible: !(root.isPlaying || audioViz.hasAudio)
          anchors.verticalCenter: parent.verticalCenter
        }

        // Track snippet if playing, or "System Pulse" badge if idle
        Text {
          text: (root.isPlaying || audioViz.hasAudio)
            ? (root.trackTitle ? (root.trackTitle.length > 18 ? root.trackTitle.substring(0, 16) + "…" : root.trackTitle) : "Playing")
            : "System Pulse"
          color: (root.isPlaying || audioViz.hasAudio) ? (root.bar ? root.bar.barForeground : Color.bar.text) : Qt.darker(root.bar ? root.bar.barForeground : Color.bar.text, 1.6)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: (root.isPlaying || audioViz.hasAudio)
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // 6. Dynamic Cloud Sync Event State
      Row {
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.isSyncing

        Rectangle {
          width: 1
          height: Style.space(14)
          color: root.bar ? root.bar.barForeground : Color.bar.text
          opacity: 0.25
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "󰓦"
          color: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.syncSpeed !== "0 B/s" ? root.syncSpeed : (Math.round(root.syncPct) + "%")
          color: root.bar ? root.bar.barForeground : Color.bar.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // 7. Dynamic Study Focus Event State
      Row {
        spacing: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.isStudying

        Rectangle {
          width: 1
          height: Style.space(14)
          color: root.bar ? root.bar.barForeground : Color.bar.text
          opacity: 0.25
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: "󰅶"
          color: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          property int mins: Math.floor(root.studyRemainingSecs / 60)
          property int secs: root.studyRemainingSecs % 60
          text: (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs)
          color: root.bar ? root.bar.barForeground : Color.bar.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

    }

    MouseArea {
      id: islandMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      z: 0

      onEntered: {
        if (root.bar && typeof root.bar.setCenterSectionHovered === "function") {
          root.bar.setCenterSectionHovered(true)
        }
      }

      onExited: {
        if (root.bar && typeof root.bar.setCenterSectionHovered === "function") {
          root.bar.setCenterSectionHovered(false)
        }
      }

      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
          root.toggle()
        } else if (mouse.button === Qt.RightButton) {
          root.togglePlayPause()
        } else if (mouse.button === Qt.MiddleButton) {
          root.nextTrack()
        }
      }
    }
  }

  SystemPlusDashboard {
    id: dashboard
    anchorItem: islandSurface
    bar: root.bar
    mediaService: root
    visualizerService: audioViz
    anchorHovered: islandMouse.containsMouse
  }
}
