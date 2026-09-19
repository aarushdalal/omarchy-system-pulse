# Omarchy Plugin Marketplace Submission Package

This document contains the finalized, copy-pasteable submission metadata and maintainer notes for publishing **System Pulse** (`daemon0.system-pulse`) to the official Omarchy Plugin Marketplace.

---

## 📋 Marketplace Form Submission Fields

Copy and paste the exact values below into each field of the Omarchy Plugin Submission Form:

### **Repository URL**
```text
https://github.com/aarushdalal/omarchy-system-pulse
```

### **Plugin Identifier**
```text
daemon0.system-pulse
```

### **Display Name**
```text
System Pulse
```

### **Category**
```text
System
```

### **Tags**
```text
System, hardware-monitoring, audio-visualizer, fan-control, wayland, quickshell, hyprland
```

### **Suggest a missing tag**
```text
utility, hardware-control
```

---

### **Maintainer notes** (Copy & Paste Text)

```text
System Pulse is an easy-to-use, GUI-based system monitoring and hardware control plugin designed to give Omarchy users a comprehensive overview and tactile control of their machine in one unified, glassmorphic interface.

Designed specifically for Wayland and built on Quickshell, System Pulse integrates directly into the Omarchy bar as an interactive island widget, expanding into an organized multi-card dashboard.

### Core Modules & Features:

1. **Compute & Engine Telemetry**
   - Real-time per-core and aggregate CPU load tracking.
   - GPU utilization, core clocks, and VRAM memory metrics (supports AMDGPU, Intel, and NVIDIA via sysfs / hwmon).
   - System memory consumption with swap and memory pressure diagnostics.
   - Live thermal tracking across CPU package, GPU hotspot, and motherboard sensors.

2. **Storage Health & Volume Matrix**
   - Live capacity breakdown across root and mounted filesystem partitions.
   - I/O activity tracking and disk thermal monitoring.
   - Drive health and wear indicator statuses.

3. **Audio Studio & Low-Latency Visualizer**
   - Interactive MPRIS media player with artwork display, title/artist tracking, and responsive playback/seek controls.
   - Hardware volume level and mute toggles with sink synchronization.
   - Real-time 18-band audio spectrum analyzer powered by a native in-memory PCM capture engine (<5ms latency, zero buffering lag) interfacing directly with PipeWire / PulseAudio.

4. **Hardware Fan Curve Studio & Calibration**
   - Live tachometer displaying real-time cooling fan RPM.
   - Interactive thermal curve visualizer with an animated operating-point tracker.
   - 4 built-in cooling presets for quick setup: Silent, Balanced, Turbo, and Max (100% RPM).
   - Instant manual burst test trigger to verify physical fan response and acoustic profile.

5. **Weather & Environmental Telemetry**
   - Geo-located local weather conditions, feels-like temperatures, humidity, and wind velocity.
   - Non-blocking background caching with atomic cache writes.

6. **Calendar Deck & System Controls**
   - Monthly calendar grid view.
   - Quick-access controls for volume, brightness, and audio devices.

---

### Security Architecture & Sandboxing:

- **Atomic POSIX File-Descriptor Store (`fan-config-store`)**: All user configuration and custom fan curves are stored using native `openat(2)`, `O_NOFOLLOW`, `O_CREAT | O_EXCL`, `fsync(2)`, and atomic `renameat(2)` within secure, ownership-validated `0700` directories. Symlink traversal, arbitrary file overwrite, and shell-injection vulnerabilities are eliminated by design.
- **Process Isolation**: All background process runners enforce `clearEnvironment: true`, invoking trusted absolute binary paths (`/usr/bin/...`) with strict, minimal explicit environments (`PATH=/usr/bin:/bin`, `LC_ALL=C`).
- **Zero Elevated Privileges Required**: Runs entirely in user-space. Hardware interactions query standard Linux `/sys/class/hwmon` and `/proc` interfaces.

---

### Hardware Compatibility & Graceful Degradation Disclosures:

- **Fan Speed Control**: Writing PWM fan curves requires the host motherboard/laptop embedded controller (EC) to expose writable PWM interfaces under `/sys/class/hwmon` (e.g. `nct6775`, `it87`, `asus_wmi`, `thinkpad_acpi`, `amdgpu`). If the hardware does not expose writable PWM controls or requires custom kernel modules, System Pulse automatically and gracefully degrades to read-only RPM/thermal monitoring without UI breakage or errors.
- **Audio Spectrum Engine**: The low-latency visualizer automatically compiles an optimized C helper (`audio-spectrum.c`) using `libpulse-simple`. If `gcc` or `libpulse` development headers are not installed, the plugin gracefully falls back to standard MPRIS media controls with simulated ambient spectrum animation.
- **Dependencies**: Works out of the box on standard Omarchy installations. Optional runtime dependencies: `curl` (weather data), `playerctl` (MPRIS media commands), `lm_sensors` (extended sensor labels), `gcc` and `libpulse` (for native 60 FPS spectrum visualizer).
```

---

## 🛠️ Verification & Validation Checklist

Before submitting the form, ensure these commands pass in the local repository:

```bash
# 1. Validate manifest schema
omarchy plugin validate .

# 2. Verify git status is clean and up to date
git status
git log -n 1 --oneline
```
