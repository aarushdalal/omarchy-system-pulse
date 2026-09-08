import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool active: true
  property var bars: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property int updateSeq: 0
  property bool hasAudio: false

  onActiveChanged: {
    if (active) {
      if (!spectrumProc.running) spectrumProc.running = true
    } else {
      if (spectrumProc.running) spectrumProc.running = false
      root.bars = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      root.hasAudio = false
      root.updateSeq++
    }
  }

  Process {
    id: spectrumProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/daemon0.system-pulse/services/audio-spectrum"]
    running: root.active
    stdout: SplitParser {
      onRead: function(line) {
        if (!line) return
        var s = String(line).trim()
        if (s === "") return
        var parts = s.split(",")
        if (parts.length >= 18) {
          var parsed = []
          var audioDetected = false
          for (var i = 0; i < 18; i++) {
            var val = Math.max(0, Math.min(100, parseInt(parts[i], 10) || 0))
            if (val > 2) audioDetected = true
            parsed.push(val)
          }
          root.bars = parsed
          root.hasAudio = audioDetected
          root.updateSeq++
        }
      }
    }
  }
}
