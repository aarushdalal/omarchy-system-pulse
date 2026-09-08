# System Pulse (`omarchy-system-pulse`)

> **Unofficial / Community Plugin**: Formerly Omni Center / System Plus. An independent open-source hardware telemetry and control center for Omarchy.

A unified center-island hardware telemetry, audio control, and quick-action dashboard designed for Omarchy Quickshell and Hyprland — displaying CPU, memory, storage, audio, fan, and weather data directly in the Omarchy top bar center island.

This project was developed through an AI-assisted workflow. The concept, customization, configuration, testing, integration, and final iteration were directed and carried out by me.

---

## My Contribution

I did not write Omarchy, Quickshell, Hyprland, or PipeWire from scratch. What I contributed:

- **Plugin Architecture**: Designed and structured this as a conformant Omarchy plugin with `manifest.json`, `BarWidget.qml`, and `SystemPulseDashboard.qml` following the Omarchy plugin system conventions.
- **Bar Widget**: Designed and implemented `BarWidget.qml` as the center-island widget showing live CPU load, memory, and audio indicators in the Omarchy top bar at all times.
- **Dashboard Panel**: Designed and built `SystemPulseDashboard.qml` — the expandable multi-tab hardware management center.
- **Telemetry Cards**: Designed and authored all 7 card QML components in `cards/`:
  - `ComputeCard.qml`: CPU core utilization, load averages, memory consumption, thermal readings.
  - `StorageCard.qml`: Filesystem disk space and partition health.
  - `AudioCard.qml`: Physical volume sliders, output sink selection, MPRIS media controls.
  - `DeckCard.qml`: Quick-action shortcuts and system controls.
  - `FanCard.qml`: Fan speed telemetry and optional profile switching.
  - `WeatherCard.qml`: Lightweight weather summary via `wttr.in`.
  - `SettingsCard.qml`: Plugin configuration and display toggles.
- **Audio Visualization**: Integrated optional lightweight audio spectrum visualization connecting to PipeWire / PulseAudio via `libpulse-simple` (C source: `audio_spectrum.c` in omarchy-screensaver-studio, shared library approach).
- **Hardware Sensor Reading**: Implemented metric collection via standard Linux `/proc`, `/sys`, and D-Bus interfaces — without root privileges.
- **Fan Curve Configuration**: Designed `fan-curve.json` format for thermal management profiles.
- **Installer**: Authored `./install.sh` for safe user-scope deployment.
- **Documentation**: Wrote all usage, configuration, and troubleshooting docs.
- **Testing**: Tested on Omarchy 4.0.2 / Quickshell 0.3.1 / PipeWire 1.6.8 on AMD Ryzen 7 PRO 5850U hardware.

---

## Based On / Credits

- **[Omarchy](https://github.com/basecamp/omarchy)** — The open-source Arch Linux desktop environment and plugin system by Basecamp. This plugin uses the Omarchy plugin manifest format and bar widget API.
- **[Quickshell](https://quickshell.outfoxxed.me)** — The Qt6 QML Wayland layer-shell desktop shell that renders the center-island widget and dashboard.
- **[Hyprland](https://hyprland.org)** — The Wayland tiling compositor.
- **[PipeWire](https://pipewire.org)** — The audio server. Audio controls and visualization read from PipeWire via WirePlumber and `libpulse-simple`.
- **[wttr.in](https://wttr.in)** — Public weather API used for the optional weather card.
- **`lm_sensors`** — Used for hardware thermal and fan sensor reading.
- **`playerctl`** — Used for MPRIS media transport controls.

**Related Repos**:
- [omarchy-cloud-sync](https://github.com/aarushdalal/omarchy-cloud-sync) — Cloud backup dashboard
- [omarchy-config-time-machine](https://github.com/aarushdalal/omarchy-config-time-machine) — Configuration snapshot system
- [omarchy-focus-hub](https://github.com/aarushdalal/omarchy-focus-hub) — Pomodoro and focus session manager
- [omarchy-screensaver-studio](https://github.com/aarushdalal/omarchy-screensaver-studio) — Multi-mode screensaver engine
- [omarchy-shell-polish](https://github.com/aarushdalal/omarchy-shell-polish) — Bar layout and shell polish snippets

---

## Plugin Manifest

This repository includes a valid `manifest.json` for the Omarchy plugin system:

```json
{
  "schemaVersion": 1,
  "id": "daemon0.system-pulse",
  "name": "System Pulse",
  "version": "1.0.0",
  "author": "Daemon0",
  "description": "Unified system telemetry, audio controls, and hardware management center for Omarchy",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "barWidget": {
    "displayName": "System Pulse",
    "category": "System",
    "allowMultiple": false,
    "defaultSection": "center"
  }
}
```

---

## Features

- **Compute Telemetry**: Real-time CPU core utilization, load averages, memory consumption, and thermal readings.
- **Storage Metrics**: Filesystem disk space usage and partition health.
- **Audio Control Center**: Physical volume sliders, output sink selection, and MPRIS media player controls (play/pause/next/previous).
- **Audio Visualization (Optional)**: Lightweight spectrum visualization via `libpulse-simple` (compiled from source).
- **Fan Controls & Profiles**: Fan speed telemetry and optional curve switching where supported.
- **Weather Widget**: Optional lightweight weather summary via `wttr.in`.
- **Center Island Placement**: Designed for the center section of the Omarchy top bar (`defaultSection: center`).

---

## Requirements

- **Operating System**: Arch Linux (rolling release, x86_64)
- **Desktop Shell**: Omarchy (`dev (13f18b2c) / 4.0.2`) with Quickshell (`0.3.1`)
- **Compositor**: Hyprland (`0.56.2`)
- **Core Dependencies**: `bash`, `jq`
- **Optional Dependencies**:
  - `pipewire`, `pipewire-pulse` (for audio routing and visualizer)
  - `playerctl` (for MPRIS media transport controls)
  - `lm_sensors` (for thermal sensors)
  - `curl` (for weather forecasts)
  - `gcc`, `libpulse` (for compiling optional audio spectrum visualizer)

---

## Compatibility

| Component | Tested Version | Compatibility Status |
|---|---|---|
| Omarchy | `dev (13f18b2c) / 4.0.2` | Fully compatible |
| Quickshell | `0.3.1` | Fully compatible |
| Hyprland | `0.56.2` | Fully compatible |
| Audio | PipeWire 1.6.8 / Pulse | Fully compatible |

---

## Installation

### Method 1: Using Omarchy Plugin Manager (Recommended)

```bash
omarchy plugin add https://github.com/aarushdalal/omarchy-system-pulse.git --enable
```

### Method 2: Using the Safe User Installer

```bash
git clone https://github.com/aarushdalal/omarchy-system-pulse.git
cd omarchy-system-pulse

./install.sh check
./install.sh install --dry-run
./install.sh install
```

---

## System Setup Before Installation

1. **Verify Audio and Sensors**:
   ```bash
   wpctl status       # PipeWire audio sink status
   sensors            # Verify hardware temperature sensors
   playerctl status   # Check active media players
   ```
2. **Never Requires Root**: System Pulse reads standard unprivileged sysfs paths. Do not run as root.

---

## Usage

- Click the center-bar widget to open the full System Pulse dashboard.
- Cycle through tabs: **Compute**, **Storage**, **Audio**, **Deck**, **Fan**, **Weather**.

---

## Configuration

- Center anchor placement in `~/.config/omarchy/shell.json`:
  ```json
  {
    "bar": {
      "centerAnchor": "daemon0.system-pulse",
      "layout": {
        "center": [
          { "id": "omarchy.indicators" },
          { "id": "daemon0.system-pulse" }
        ]
      }
    }
  }
  ```

---

## Update

```bash
omarchy plugin update daemon0.system-pulse
```

---

## Uninstall

```bash
./install.sh uninstall
# Or:
omarchy plugin remove daemon0.system-pulse --yes
```

---

## Security and Privacy

- Telemetry is queried purely locally on your machine.
- Weather queries fetch city temperature via public HTTPS without tracking.
- No personal data or audio recording is logged or transmitted.

---

## Troubleshooting

- **Audio visualizer does not show activity**: Ensure `libpulse-simple` headers are installed (`sudo pacman -S libpulse`) and re-run `./install.sh install` to compile the spectrum helper.
- **Fan speeds not visible**: Run `sensors-detect` to check if your motherboard provides standard `hwmon` fan sensors.

---

## Showcase

![Compute telemetry](assets/showcase/system_plus_compute.png)
![Audio control](assets/showcase/system_plus_audio.png)
![System deck](assets/showcase/system_plus_deck.png)
![Fan telemetry](assets/showcase/system_plus_fan.png)
![Storage metrics](assets/showcase/system_plus_storage.png)
![Weather widget](assets/showcase/system_plus_weather.png)

---

## Contributing

Issues and enhancements are welcome!

---

## License

[MIT License](LICENSE).

---

## Credits / Third-Party Notices

- Built for the [Omarchy](https://github.com/basecamp/omarchy) desktop environment.
- Powered by [Quickshell](https://quickshell.outfoxxed.me/), [Hyprland](https://hyprland.org/), and [PipeWire](https://pipewire.org/).
- Not an official Omarchy product.
