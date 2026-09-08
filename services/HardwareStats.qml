import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool active: false

  property int cpuComputePercent: 0
  property int cpuBusyPercent: 0
  property string cpuFreqGhz: "3.5"
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

  property int nvmeTemp: 0
  property var rootDisk: ({ name: "System Root (/)", total: 187, used: 60, free: 127, pct: 32 })
  property var volume2Disk: null
  property string smartStatus: "Healthy"

  property int batteryPercent: 100
  property string batteryStatus: "AC"
  property int totalPower: 0
  property bool btopInstalled: true

  // 20-Point History Buffers for Live Waveform Graphs
  property var cpuHistory: [10, 15, 12, 18, 25, 30, 28, 35, 40, 45, 50, 48, 52, 55, 50, 42, 38, 30, 25, 20]
  property var gpuHistory: [5, 8, 4, 12, 15, 10, 18, 22, 15, 12, 8, 14, 20, 18, 12, 10, 8, 6, 4, 3]

  // Internal state for CPU deltas
  property real lastCpuTotal: 0
  property real lastCpuIdle: 0
  property real lastCpuCompute: 0

  function refresh() {
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
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: collectorProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/daemon0.system-pulse/services/stats-collector.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || text.trim() === "") return
        try {
          var data = JSON.parse(text.trim())
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

          if (data.storage) {
            root.nvmeTemp = Number(data.storage.nvme_temp) || 0
            if (data.storage.root) root.rootDisk = data.storage.root
            root.volume2Disk = data.storage.volume2 || null
            root.smartStatus = data.storage.smart || "Healthy"
          }

          if (data.battery) {
            root.batteryPercent = Number(data.battery.pct) || 100
            root.batteryStatus = String(data.battery.status || "AC")
          }

          if (typeof data.btop_installed === "boolean") {
            root.btopInstalled = data.btop_installed
          }

          root.totalPower = Math.max(root.gpuPower, 15) + (root.batteryStatus === "Discharging" ? 10 : 5)
        } catch (e) {
          // Ignore parse errors
        }
      }
    }
  }
}
