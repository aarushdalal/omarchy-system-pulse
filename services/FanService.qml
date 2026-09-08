import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  required property var hardwareStats

  property string profile: "balanced"
  property bool maxTestMode: false
  property int maxRpm: 5800

  // 6 Thermal Curve Control Points: [{ temp: °C, speed: % }]
  property var curve: [
    { "temp": 40, "speed": 0 },
    { "temp": 50, "speed": 25 },
    { "temp": 62, "speed": 50 },
    { "temp": 75, "speed": 75 },
    { "temp": 85, "speed": 90 },
    { "temp": 95, "speed": 100 }
  ]

  readonly property var presets: ({
    "silent": [
      { "temp": 45, "speed": 0 },
      { "temp": 55, "speed": 15 },
      { "temp": 68, "speed": 40 },
      { "temp": 80, "speed": 70 },
      { "temp": 90, "speed": 90 },
      { "temp": 98, "speed": 100 }
    ],
    "balanced": [
      { "temp": 40, "speed": 0 },
      { "temp": 50, "speed": 25 },
      { "temp": 62, "speed": 50 },
      { "temp": 75, "speed": 75 },
      { "temp": 85, "speed": 90 },
      { "temp": 95, "speed": 100 }
    ],
    "performance": [
      { "temp": 35, "speed": 25 },
      { "temp": 48, "speed": 50 },
      { "temp": 60, "speed": 75 },
      { "temp": 72, "speed": 88 },
      { "temp": 82, "speed": 95 },
      { "temp": 92, "speed": 100 }
    ],
    "turbo": [
      { "temp": 30, "speed": 100 },
      { "temp": 45, "speed": 100 },
      { "temp": 60, "speed": 100 },
      { "temp": 75, "speed": 100 },
      { "temp": 85, "speed": 100 },
      { "temp": 95, "speed": 100 }
    ]
  })

  // Live calculated speed percentage based on current CPU temp
  readonly property int currentPercent: {
    if (root.maxTestMode) return 100

    var temp = root.hardwareStats ? (root.hardwareStats.cpuTemp || 55) : 55
    if (temp <= root.curve[0].temp) {
      return root.curve[0].speed
    }
    if (temp >= root.curve[root.curve.length - 1].temp) {
      return root.curve[root.curve.length - 1].speed
    }

    for (var i = 0; i < root.curve.length - 1; i++) {
      var p1 = root.curve[i]
      var p2 = root.curve[i + 1]
      if (temp >= p1.temp && temp <= p2.temp) {
        var ratio = (temp - p1.temp) / Math.max(1, p2.temp - p1.temp)
        var spd = p1.speed + ratio * (p2.speed - p1.speed)
        return Math.max(0, Math.min(100, Math.round(spd)))
      }
    }
    return 50
  }

  // Live Fan RPM
  readonly property int currentRpm: Math.round((currentPercent / 100.0) * root.maxRpm)

  // Acoustic noise estimate in dBA
  readonly property int acousticDba: {
    if (currentPercent <= 0) return 0
    if (currentPercent < 30) return 18
    if (currentPercent < 60) return 24
    if (currentPercent < 85) return 32
    return 39
  }

  function applyPreset(name) {
    if (root.presets[name]) {
      root.profile = name
      root.curve = JSON.parse(JSON.stringify(root.presets[name]))
      root.maxTestMode = (name === "turbo")
      save()
    }
  }

  function updatePointSpeed(index, newSpeed) {
    if (index >= 0 && index < root.curve.length) {
      var updated = JSON.parse(JSON.stringify(root.curve))
      updated[index].speed = Math.max(0, Math.min(100, Math.round(newSpeed)))
      root.curve = updated
      root.profile = "custom"
      save()
    }
  }

  function toggleMaxTest() {
    root.maxTestMode = !root.maxTestMode
    save()
  }

  // Persistent File Storage: ~/.config/omarchy/fan-curve.json
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/fan-curve.json"

  function save() {
    var data = {
      "profile": root.profile,
      "maxTestMode": root.maxTestMode,
      "curve": root.curve
    }
    saveProc.command = [
      "bash", "-c",
      "cat > '" + root.configPath + "' << 'EOF'\n" + JSON.stringify(data, null, 2) + "\nEOF"
    ]
    saveProc.running = true
  }

  function load() {
    loadProc.command = ["cat", root.configPath]
    loadProc.running = true
  }

  Process {
    id: saveProc
  }

  Process {
    id: loadProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || text.trim() === "") return
        try {
          var cfg = JSON.parse(text.trim())
          if (cfg.profile) root.profile = cfg.profile
          if (typeof cfg.maxTestMode === "boolean") root.maxTestMode = cfg.maxTestMode
          if (Array.isArray(cfg.curve) && cfg.curve.length === 6) {
            root.curve = cfg.curve
          }
        } catch (e) {}
      }
    }
  }

  Component.onCompleted: load()
}
