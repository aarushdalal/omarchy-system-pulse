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

  readonly property string spectrumBinaryPath: {
    var raw = Qt.resolvedUrl("audio-spectrum").toString()
    if (raw.indexOf("file://") === 0) raw = raw.substring(7)
    return raw
  }

  Process {
    id: spectrumProc
    command: [root.spectrumBinaryPath]
    clearEnvironment: true
    environment: ({
      "PATH": "/usr/bin:/bin",
      "LC_ALL": "C",
      "XDG_RUNTIME_DIR": Quickshell.env("XDG_RUNTIME_DIR") || "",
      "PULSE_SERVER": Quickshell.env("PULSE_SERVER") || ""
    })
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
