import QtQuick
import Quickshell
import Quickshell.Io
import "StorageState.js" as StorageState

Item {
  id: root

  property bool active: false

  property int cpuComputePercent: 0
  property int cpuBusyPercent: 0
  property string cpuFreqGhz: "—"
  property int cpuTemp: 0

  property int gpuPercent: 0
  property int gpuVramUsed: 0
  property int gpuVramTotal: 512
  property int gpuVramPercent: 0
  property int gpuGttUsed: 0
  property int gpuGttTotal: 8192
  property int gpuTemp: 0
  property int gpuPower: 0

  property int ramUsed: 0
  property int ramTotal: 0
  property int ramPercent: 0
  property int swapUsed: 0
  property int swapTotal: 0
  property int swapPercent: 0

  property var storageSample: null
  property bool storageSampled: false
  property double storageSampledAtMs: 0
  property double storageNowMs: Date.now()
  property string storageError: ""
  // Three polling intervals, with a 5 s floor, tolerates ordinary scheduling jitter.
  readonly property int storageStaleAfterMs: Math.max(5000, pollTimer.interval * 3)
  readonly property var storageState: StorageState.snapshot(storageSample, storageSampledAtMs,
      storageNowMs, storageStaleAfterMs, storageError, storageSampled)
  readonly property var nvmeTemp: storageState.nvmeTemp
  readonly property var rootDisk: storageState.root
  readonly property var volume2Disk: storageState.volume2
  readonly property string smartStatus: storageState.smartText

  property int batteryPercent: 100
  property string batteryStatus: "AC"
  property int totalPower: 0
  property bool btopInstalled: true

  // 20-Point History Buffers for Live Waveform Graphs
  property var cpuHistory: Array(20).fill(0)
  property var gpuHistory: Array(20).fill(0)

  // Internal state for CPU deltas
  property real lastCpuTotal: 0
  property real lastCpuIdle: 0
  property real lastCpuCompute: 0

  function refresh() {
    root.storageNowMs = Date.now()
    if (!collectorProc.running) {
      collectorProc.running = true
    }
  }

  onActiveChanged: {
    if (active) {
      refresh()
      pollTimer.interval = 1000
    } else {
      pollTimer.interval = 5000
    }
  }

  Timer {
    id: pollTimer
    interval: root.active ? 1000 : 5000
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  readonly property string collectorPath: {
    var raw = Qt.resolvedUrl("stats-collector.sh").toString()
    if (raw.indexOf("file://") === 0) raw = raw.substring(7)
    return raw
  }

  Process {
    id: collectorProc
    command: ["/usr/bin/bash", root.collectorPath]
    clearEnvironment: true
    environment: ({
      "PATH": "/usr/bin:/bin",
      "LC_ALL": "C",
      "HOME": Quickshell.env("HOME") || ""
    })
    stdout: StdioCollector {
      id: collectorOutput
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      // Commit output only after a successful exit. A failed command may have
      // printed a plausible partial JSON sample before reporting an error.
      if (exitCode !== 0 || exitStatus !== 0) {
        root.storageNowMs = Date.now()
        root.storageError = "collector-exit"
        return
      }
      root.storageNowMs = Date.now()
      if (!collectorOutput.text || collectorOutput.text.trim() === "") {
        root.storageError = "empty-output"
        return
      }
      try {
        var data = JSON.parse(collectorOutput.text.trim())
        if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("Invalid sample")
        if (data.storage !== undefined && data.storage !== null
            && (typeof data.storage !== "object" || Array.isArray(data.storage))) throw new Error("Invalid storage sample")
        root.storageSample = data.storage || null
        root.storageSampled = true
        root.storageSampledAtMs = root.storageNowMs
        root.storageError = ""
        if (data.cpu) {
          var curTotal = Number(data.cpu.total) || 0
          var curIdle = Number(data.cpu.idle) || 0
          var curCompute = Number(data.cpu.compute) || 0

          if (root.lastCpuTotal > 0) {
            var dTotal = curTotal - root.lastCpuTotal
            var dIdle = curIdle - root.lastCpuIdle
            var dCompute = curCompute - root.lastCpuCompute

            if (dTotal > 0) {
              // Compute % (Pure calculation load)
              var compPct = Math.round(100 * (dCompute / dTotal))
              root.cpuComputePercent = Math.max(0, Math.min(100, compPct))

              // Total Busy % (Compute + I/O Wait)
              var busyPct = Math.round(100 * (1.0 - (dIdle / dTotal)))
              root.cpuBusyPercent = Math.max(root.cpuComputePercent, Math.min(100, busyPct))
            }
          }

          root.lastCpuTotal = curTotal
          root.lastCpuIdle = curIdle
          root.lastCpuCompute = curCompute

          root.cpuTemp = Number(data.cpu.temp) || 0
          var freqMhz = Number(data.cpu.freq_mhz) || 3500
          root.cpuFreqGhz = (freqMhz / 1000).toFixed(1)

          // Update CPU history sparkline
          var nextCpuHist = root.cpuHistory.slice(1)
          nextCpuHist.push(root.cpuBusyPercent)
          root.cpuHistory = nextCpuHist
        }

        if (data.gpu) {
          root.gpuPercent = Number(data.gpu.util) || 0
          root.gpuVramUsed = Number(data.gpu.vram_used) || 0
          root.gpuVramTotal = Number(data.gpu.vram_tot) || 512
          root.gpuVramPercent = root.gpuVramTotal > 0 ? Math.round(100 * root.gpuVramUsed / root.gpuVramTotal) : 0
          root.gpuGttUsed = Number(data.gpu.gtt_used) || 0
          root.gpuGttTotal = Number(data.gpu.gtt_tot) || 8192
          root.gpuTemp = Number(data.gpu.temp) || 0
          root.gpuPower = Number(data.gpu.power) || 0

          // Update GPU history sparkline
          var nextGpuHist = root.gpuHistory.slice(1)
          nextGpuHist.push(root.gpuPercent)
          root.gpuHistory = nextGpuHist
        }

        if (data.ram) {
          root.ramTotal = Number(data.ram.total) || 0
          root.ramUsed = Number(data.ram.used) || 0
          root.ramPercent = root.ramTotal > 0 ? Math.round(100 * root.ramUsed / root.ramTotal) : 0
          root.swapTotal = Number(data.ram.swap_total) || 0
          root.swapUsed = Number(data.ram.swap_used) || 0
          root.swapPercent = root.swapTotal > 0 ? Math.round(100 * root.swapUsed / root.swapTotal) : 0
        }

        if (data.battery) {
          root.batteryPercent = Math.max(0, Math.min(100, Number(data.battery.pct) || 0))
          root.batteryStatus = String(data.battery.status || "AC")
        }

        if (typeof data.btop_installed === "boolean") {
          root.btopInstalled = data.btop_installed
        }

        root.totalPower = Math.max(root.gpuPower, 15) + (root.batteryStatus === "Discharging" ? 10 : 5)
      } catch (e) {
        root.storageError = "invalid-output"
      }
    }
  }
}
