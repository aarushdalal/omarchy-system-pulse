#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mode=$(cat fixture-mode)
case "$mode" in
  partial) echo '{"cpu":{"total":100,"idle":50,"compute":50,"temp":60,"freq_mhz":2000},"ram":{"total":16000,"used":8000},"storage":{"root":{"name":"Root","total":187,"used":148,"free":38,"pct":80},"nvme_temp":0,"smart":{"state":"unavailable","reason":"not-collected"}}}' ;;
  error) echo '{"storage":' ;;
  exit) echo '{"storage":{"root":{"name":"Failed","total":10,"used":1,"free":9,"pct":10},"nvme_temp":70}}'; exit 2 ;;
  unavailable) echo '{"storage":null}' ;;
  unsupported) echo '{"storage":{"state":"unsupported"}}' ;;
  valid) echo '{"storage":{"root":{"name":"Root","total":187,"used":148,"free":38,"pct":80},"nvme_temp":36,"smart":{"state":"valid","status":"Passed"}}}' ;;
esac
