#!/usr/bin/env bash
# ==============================================================================
# Installer for System Pulse (daemon0.system-pulse)
# Safe user-scope installer with --dry-run and rollback support
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
TARGET_PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/daemon0.system-pulse"
BACKUP_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/backups/daemon0.system-pulse"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=1
  fi
done

run_cmd() {
  if (( DRY_RUN )); then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

check_deps() {
  echo "Checking requirements for System Pulse..."
  local missing=0

  if command -v omarchy >/dev/null 2>&1; then
    echo "  [OK] Omarchy is installed ($(omarchy --version 2>/dev/null || echo 'active'))"
  else
    echo "  [FAIL] Omarchy CLI is required."
    missing=1
  fi

  if command -v quickshell >/dev/null 2>&1; then
    echo "  [OK] Quickshell is installed ($(quickshell --version 2>/dev/null || echo 'active'))"
  else
    echo "  [FAIL] Quickshell is required."
    missing=1
  fi

  if command -v python3 >/dev/null 2>&1; then
    echo "  [OK] Python 3 is installed ($(python3 --version 2>&1))"
  else
    echo "  [FAIL] Python 3 is required."
    missing=1
  fi

  if command -v jq >/dev/null 2>&1; then
    echo "  [OK] jq is installed"
  else
    echo "  [FAIL] jq is required."
    missing=1
  fi

  if (( missing )); then
    echo "Error: Required dependencies are missing. Please install them before proceeding." >&2
    return 1
  fi
  echo "All required dependencies are satisfied."
  return 0
}

do_backup() {
  if [[ -d "$TARGET_PLUGIN_DIR" ]]; then
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local bdir="$BACKUP_BASE/$ts"
    echo "Creating backup of existing plugin at $bdir"
    if (( ! DRY_RUN )); then
      mkdir -p "$bdir"
      cp -r "$TARGET_PLUGIN_DIR" "$bdir/"
    else
      echo "[DRY-RUN] mkdir -p '$bdir' && cp -r '$TARGET_PLUGIN_DIR' '$bdir/'"
    fi
  fi
}

do_install() {
  check_deps || exit 1
  do_backup

  echo "Installing System Pulse to $TARGET_PLUGIN_DIR..."
  run_cmd mkdir -p "$TARGET_PLUGIN_DIR"

  for item in "$SCRIPT_DIR"/*; do
    local base="$(basename "$item")"
    case "$base" in
      install.sh|README.md|LICENSE|CHANGELOG.md|project-manifest.json|docs|assets|.git|.gitignore|bin|hooks|systemd|examples)
        ;;
      *)
        run_cmd cp -r "$item" "$TARGET_PLUGIN_DIR/"
        ;;
    esac
  done

  
  # Optional compilation of native audio spectrum analyzer
  if [[ -f "$TARGET_PLUGIN_DIR/services/audio-spectrum.c" ]]; then
    if command -v gcc >/dev/null 2>&1 && pkg-config --exists libpulse-simple 2>/dev/null; then
      echo "Compiling native audio spectrum visualizer (optional)..."
      run_cmd gcc -O3 -Wall -Wextra "$TARGET_PLUGIN_DIR/services/audio-spectrum.c" -o "$TARGET_PLUGIN_DIR/services/audio-spectrum" $(pkg-config --cflags --libs libpulse-simple) -lm 2>/dev/null || echo "Note: Audio visualizer compilation skipped; audio card will operate without native spectrum."
    else
      echo "Note: gcc or libpulse-simple development headers not found. Audio spectrum analyzer compilation skipped."
    fi
  fi


  echo "Validating installed plugin with Omarchy..."
  if (( ! DRY_RUN )); then
    if command -v omarchy >/dev/null 2>&1; then
      omarchy plugin validate "$TARGET_PLUGIN_DIR"
      omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    fi
  fi

  echo "System Pulse installed successfully!"
  echo "To enable in Omarchy bar: omarchy plugin enable daemon0.system-pulse"
}

do_status() {
  echo "=== System Pulse Status ==="
  if [[ -d "$TARGET_PLUGIN_DIR" ]]; then
    echo "  Installed at: $TARGET_PLUGIN_DIR"
    if [[ -f "$TARGET_PLUGIN_DIR/manifest.json" ]]; then
      local ver
      ver=$(jq -r '.version // "unknown"' "$TARGET_PLUGIN_DIR/manifest.json")
      echo "  Version: $ver"
    fi
  else
    echo "  Not installed in user plugins directory."
  fi

  if command -v omarchy >/dev/null 2>&1; then
    echo -n "  Omarchy plugin state: "
    omarchy plugin list 2>/dev/null | grep "daemon0.system-pulse" || echo "Not registered/disabled"
  fi
}

do_uninstall() {
  echo "Uninstalling System Pulse..."
  if command -v omarchy >/dev/null 2>&1; then
    run_cmd omarchy plugin disable "daemon0.system-pulse" >/dev/null 2>&1 || true
  fi

  if [[ -d "$TARGET_PLUGIN_DIR" ]]; then
    do_backup
    echo "Removing $TARGET_PLUGIN_DIR"
    run_cmd rm -rf "$TARGET_PLUGIN_DIR"
  fi

  echo "System Pulse uninstalled cleanly. Reversible backups preserved under $BACKUP_BASE."
}

case "${1:-check}" in
  check)
    check_deps
    ;;
  install)
    do_install
    ;;
  update)
    echo "Updating System Pulse..."
    do_install
    ;;
  status)
    do_status
    ;;
  uninstall)
    do_uninstall
    ;;
  *)
    echo "Usage: $0 {check|install|update|status|uninstall} [--dry-run]"
    exit 1
    ;;
esac
