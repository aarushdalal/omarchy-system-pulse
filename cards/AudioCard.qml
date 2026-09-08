import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

Item {
  id: root

  required property var mediaService
  required property var visualizerService
  required property color foregroundColor
  required property string fontFamily

  function isWallpaperOrDummy(p) {
    if (!p) return true;
    var name = String(p.identity || p.desktopEntry || p.dbusName || "").toLowerCase();
    var track = String(p.trackTitle || "").toLowerCase();
    if (name.indexOf("mpvpaper") !== -1 || name.indexOf("paper") !== -1) return true;
    if (name.indexOf("mpv") !== -1 && (track.indexOf(".mp4") !== -1 || track.indexOf(".mkv") !== -1 || track.indexOf(".webm") !== -1 || track === "" || track === "no media playing")) {
      return true;
    }
    return false;
  }

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
  readonly property string title: activePlayer && activePlayer.trackTitle ? activePlayer.trackTitle : "No Media Playing"
  readonly property string artist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : "Ready"
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""

  readonly property real rawLength: {
    if (!activePlayer) return 0
    if (activePlayer.trackLength && activePlayer.trackLength > 0) return Number(activePlayer.trackLength)
    if (activePlayer.length && activePlayer.length > 0) return Number(activePlayer.length)
    if (activePlayer.metadata) {
      if (activePlayer.metadata["mpris:length"]) return Number(activePlayer.metadata["mpris:length"])
      if (activePlayer.metadata.length) return Number(activePlayer.metadata.length)
    }
    return 0
  }
  readonly property real lengthSec: rawLength > 10000 ? Math.floor(rawLength / 1000000) : rawLength

  property real localPositionSec: 0

  onActivePlayerChanged: syncPosition()

  Connections {
    target: root.activePlayer
    function onPositionChanged() { root.syncPosition() }
    function onPlaybackStateChanged() { root.syncPosition() }
    function onIsPlayingChanged() { root.syncPosition() }
    function onTrackTitleChanged() { root.syncPosition() }
  }

  function syncPosition() {
    if (!activePlayer) {
      root.localPositionSec = 0
      return
    }
    var pos = activePlayer.position || 0
    root.localPositionSec = pos > 10000 ? (pos / 1000000.0) : pos
  }

  Timer {
    interval: 500
    running: root.isPlaying && root.lengthSec > 0
    repeat: true
    onTriggered: {
      if (root.localPositionSec < root.lengthSec) {
        root.localPositionSec = Math.min(root.lengthSec, root.localPositionSec + 0.5)
      }
    }
  }

  readonly property real progressFraction: (lengthSec > 0) ? Math.min(1.0, Math.max(0.0, localPositionSec / lengthSec)) : 0.0

  // System Audio Sink Volume (PipeWire)
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property real currentVol: (audioSink && audioSink.audio) ? (audioSink.audio.volume || 0.0) : 0.8
  readonly property bool isMuted: (audioSink && audioSink.audio) ? (audioSink.audio.muted === true) : false

  Process {
    id: seekProc
  }

  function seekToFraction(frac) {
    if (!root.activePlayer || root.lengthSec <= 0) return
    var targetSec = Math.max(0, Math.min(root.lengthSec, frac * root.lengthSec))
    var targetMicro = Math.round(targetSec * 1000000)
    root.localPositionSec = targetSec

    try {
      if (typeof root.activePlayer.position !== "undefined") {
        root.activePlayer.position = targetMicro
      }
    } catch (e) {}

    var trackId = ""
    if (root.activePlayer.metadata && root.activePlayer.metadata["mpris:trackid"]) {
      trackId = String(root.activePlayer.metadata["mpris:trackid"])
    }
    var busName = root.activePlayer.dbusName || ""
    if (busName) {
      if (trackId) {
        seekProc.command = ["busctl", "--user", "call", busName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "SetPosition", "ox", trackId, String(targetMicro)]
      } else {
        seekProc.command = ["busctl", "--user", "set-property", busName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Position", "x", String(targetMicro)]
      }
      seekProc.running = true
    }
  }

  function formatTime(seconds) {
    if (!seconds || isNaN(seconds) || seconds <= 0) return "0:00"
    var mins = Math.floor(seconds / 60)
    var secs = Math.floor(seconds % 60)
    return mins + ":" + (secs < 10 ? "0" : "") + secs
  }

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

  // Bass energy for ambient glow
  readonly property real bassEnergy: (root.visualizerService && root.visualizerService.bars && root.visualizerService.bars.length > 2)
    ? Math.max(0.0, Math.min(1.0, (root.visualizerService.bars[1] + root.visualizerService.bars[2]) / 180.0))
    : 0.0

  implicitWidth: Style.space(540)
  implicitHeight: contentColumn.implicitHeight + Style.space(20)

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(14)
    spacing: Style.space(12)

    // Top Section: Large Hero Poster + Track Info + Live Spectrum Visualizer
    Rectangle {
      width: parent.width
      height: heroLayout.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      RowLayout {
        id: heroLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(16)

        // Hero Album Poster Container with Music-Reactive Ambient Glow
        Item {
          width: Style.space(100)
          height: Style.space(100)
          Layout.alignment: Qt.AlignVCenter

          // Bass-reactive Ambient Halo Glow (Square with Rounded Curve)
          Rectangle {
            anchors.centerIn: parent
            width: parent.width + Style.space(10) + (root.bassEnergy * Style.space(12))
            height: parent.height + Style.space(10) + (root.bassEnergy * Style.space(12))
            radius: Style.cornerRadius + 4
            color: Color.accent
            opacity: 0.12 + (root.bassEnergy * 0.35)

            Behavior on opacity { NumberAnimation { duration: 60 } }
            Behavior on width { NumberAnimation { duration: 60 } }
            Behavior on height { NumberAnimation { duration: 60 } }
          }

          // Main Album Poster Card (Square with subtle curved corners)
          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius + 2
            color: Style.selectedFillFor(root.foregroundColor, Color.accent)
            clip: true

            Image {
              anchors.fill: parent
              source: root.artUrl
              fillMode: Image.PreserveAspectCrop
              visible: root.artUrl !== ""
            }

            // Clean Square Placeholder if no artwork
            Rectangle {
              anchors.fill: parent
              color: Style.selectedFillFor(root.foregroundColor, Color.accent)
              visible: root.artUrl === ""
              radius: parent.radius

              Column {
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "󰝚"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(28)
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "AUDIO"
                  color: Qt.darker(root.foregroundColor, 1.8)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  font.bold: true
                }
              }
            }
          }
        }

        // Track Information & Live Visualizer
        Column {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Layout.alignment: Qt.AlignVCenter

          // Now Playing Badge
          RowLayout {
            width: parent.width
            Rectangle {
              height: Style.space(20)
              width: statusPillText.implicitWidth + Style.space(14)
              radius: Style.cornerRadius - 2
              color: Style.hoverFillFor(Color.accent, Color.accent)

              Text {
                id: statusPillText
                anchors.centerIn: parent
                text: root.isPlaying ? "󰏤 NOW PLAYING" : "󰐊 MEDIA READY"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
              }
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.activePlayer ? (root.activePlayer.identity || "Media Player") : "Local Audio"
              color: Qt.darker(root.foregroundColor, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
          }

          // Song Title
          Text {
            text: root.title
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodyLarge || Style.space(16)
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          // Artist & Album
          Text {
            text: root.artist + (root.album ? " • " + root.album : "")
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          // 18-Band Live Spectrum Visualizer Strip
          Item {
            width: parent.width
            height: Style.space(26)

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              spacing: Style.space(4)

              Repeater {
                model: 18

                Rectangle {
                  required property int index
                  width: (parent.width - 17 * Style.space(4)) / 18
                  property real rawVal: (root.visualizerService && root.visualizerService.updateSeq >= 0 && root.visualizerService.bars && root.visualizerService.bars[index] !== undefined)
                    ? root.visualizerService.bars[index]
                    : 0
                  property real targetHeight: Math.max(3, (rawVal / 100.0) * Style.space(30))
                  height: targetHeight
                  anchors.bottom: parent.bottom
                  radius: 2
                  color: Color.accent
                  opacity: 0.65 + (index % 3) * 0.15

                  Behavior on height {
                    NumberAnimation { duration: 20; easing.type: Easing.OutQuad }
                  }
                }
              }
            }
          }
        }
      }
    }

    // Seek / Position Scrubber Bar
    Rectangle {
      width: parent.width
      height: Style.space(42)
      radius: Style.cornerRadius
      color: Style.normalFillFor(root.foregroundColor, Color.accent)

      Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Style.space(12)
        spacing: Style.space(4)

        // Time labels
        RowLayout {
          width: parent.width
          Text {
            text: root.formatTime(root.localPositionSec)
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.formatTime(root.lengthSec)
            color: Qt.darker(root.foregroundColor, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
          }
        }

        // Clickable / Draggable Seek Bar Track
        Rectangle {
          id: seekTrack
          width: parent.width
          height: Style.space(6)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)
          clip: true

          Rectangle {
            width: Math.min(parent.width, Math.max(0, parent.width * root.progressFraction))
            height: parent.height
            radius: Style.cornerRadius
            color: Color.accent

            Behavior on width { NumberAnimation { duration: 150 } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: function(mouse) {
              root.seekToFraction(mouse.x / seekTrack.width)
            }
            onPositionChanged: function(mouse) {
              if (pressed) {
                root.seekToFraction(mouse.x / seekTrack.width)
              }
            }
          }
        }
      }
    }

    // Controls Row + Volume Slider
    RowLayout {
      width: parent.width
      spacing: Style.space(12)

      // Media Buttons Matrix (Shuffle, Prev, Play/Pause, Next, Loop)
      Rectangle {
        Layout.fillWidth: true
        height: Style.space(52)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(14)

          // Shuffle
          Button {
            iconText: "󰒞"
            foreground: (root.activePlayer && root.activePlayer.shuffle) ? Color.accent : Qt.darker(root.foregroundColor, 1.6)
            fontFamily: root.fontFamily
            onClicked: if (root.activePlayer && typeof root.activePlayer.shuffle !== "undefined") root.activePlayer.shuffle = !root.activePlayer.shuffle
          }

          // Previous
          Button {
            iconText: "󰒮"
            foreground: root.foregroundColor
            fontFamily: root.fontFamily
            enabled: root.activePlayer !== null
            onClicked: root.prevTrack()
          }

          // Big Hero Play/Pause
          Rectangle {
            width: Style.space(42)
            height: Style.space(42)
            radius: width / 2
            color: Color.accent

            Text {
              anchors.centerIn: parent
              text: root.isPlaying ? "󰏤" : "󰐊"
              color: Color.background
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePlayPause()
            }
          }

          // Next
          Button {
            iconText: "󰒭"
            foreground: root.foregroundColor
            fontFamily: root.fontFamily
            enabled: root.activePlayer !== null
            onClicked: root.nextTrack()
          }

          // Loop
          Button {
            iconText: "󰑖"
            foreground: (root.activePlayer && root.activePlayer.loopState && root.activePlayer.loopState !== 0) ? Color.accent : Qt.darker(root.foregroundColor, 1.6)
            fontFamily: root.fontFamily
            onClicked: {
              if (root.activePlayer && typeof root.activePlayer.loopState !== "undefined") {
                root.activePlayer.loopState = (root.activePlayer.loopState + 1) % 3
              }
            }
          }
        }
      }

      // PipeWire System Volume Slider Box
      Rectangle {
        width: Style.space(180)
        height: Style.space(52)
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.foregroundColor, Color.accent)

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(8)

          // Volume Mute Glyph
          Text {
            text: root.isMuted ? "󰝟" : (root.currentVol > 0.5 ? "󰕾" : "󰕵")
            color: root.isMuted ? Color.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.audioSink && root.audioSink.audio) {
                  root.audioSink.audio.muted = !root.audioSink.audio.muted
                }
              }
            }
          }

          // Volume Track
          Rectangle {
            id: volTrack
            Layout.fillWidth: true
            height: Style.space(6)
            radius: Style.cornerRadius
            color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.12)
            clip: true

            Rectangle {
              width: Math.min(parent.width, Math.max(0, parent.width * root.currentVol))
              height: parent.height
              radius: Style.cornerRadius
              color: root.isMuted ? Qt.darker(root.foregroundColor, 1.6) : Color.accent
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (root.audioSink && root.audioSink.audio) {
                  var v = Math.max(0.0, Math.min(1.0, mouse.x / volTrack.width))
                  root.audioSink.audio.volume = v
                }
              }
            }
          }

          Text {
            text: Math.round(root.currentVol * 100) + "%"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }
    }
  }
}
