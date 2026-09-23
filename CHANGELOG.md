# Changelog

All notable changes to `omarchy-system-pulse` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-09-22

### Security
- Hardened `services/weather-fetcher.sh` with a strict byte limit (2048 bytes) enforced at the network ingestion boundary before buffering, terminating oversized streams via SIGPIPE to prevent memory exhaustion.
- Replaced manual JSON string interpolation in `services/weather-fetcher.sh` with robust RFC 8259 serialization via `jq`, ensuring safe handling of quotes, backslashes, newlines, control characters, and Unicode.
- Eliminated vulnerable `echo | xargs` calls in `services/weather-fetcher.sh` to prevent script crashes on unmatched quotes and backslashes.
- Secured weather cache file writes using unpredictable `mktemp` temporary files with `0600` permissions and atomic replacement.
- Enforced `textFormat: Text.PlainText` across all weather-derived text sinks in `cards/WeatherCard.qml` to prevent rich-text and markup injection.
- Added defense-in-depth `textFormat: Text.PlainText` and environment isolation for media sinks in `cards/AudioCard.qml` and `BarWidget.qml`.
- Added comprehensive end-to-end security regression test suite in `tests/test_weather_security.py`.

## [1.0.2] - 2026-09-13

### Added
- Native PipeWire stream tracking and browser media reconciliation (`services/MediaTrackingService.qml`).
- Active window toplevel title reconciliation with Wayland for Chromium/Brave browsers to resolve multi-tab media desynchronization.
- Dedicated hardware volume sink tracking and mouse wheel track navigation.

### Security
- Replaced shell string interpolation and redirection in `services/FanService.qml` with a native file-descriptor based atomic no-follow store helper (`services/fan-config-store.c` and `services/fan-config-store.py`).
- Enforced validated private directory creation (`mode 0700`, owner verification) preventing symlink pre-creation and arbitrary file overwrite vulnerabilities.
- Configured all child helper processes (`FanService`, `HardwareStats`, `WeatherCard`, `AudioVisualizerService`, `ComputeCard`) to execute via trusted fixed paths with minimal explicit environments (`clearEnvironment: true`), eliminating ambient PATH manipulation.
- Hardened `weather-fetcher.sh` and `stats-collector.sh` with explicit isolated PATH, trusted binary execution, and safe user-private atomic cache storage.

## [1.0.0] - 2026-09-08

### Added
- Initial clean public release for Omarchy 4.0.2 / Arch Linux.
- Center bar widget with hardware telemetry (CPU, RAM, storage, battery, fans).
- Audio controls with MPRIS media integration and optional PipeWire spectrum visualizer.
- Graceful fallback detection when specific sensors or external tools are unavailable.
- Comprehensive safe user installer script (`install.sh`) supporting `--dry-run`.
- Full security exclusions, sanitized configurations, and complete documentation.
