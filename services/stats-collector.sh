#!/usr/bin/env bash
# High-speed enhanced telemetry collector for Omarchy System Pulse Island
set -euo pipefail
export PATH="/usr/bin:/bin"
export LC_ALL="C"

# CPU utilization & compute vs io-wait
read -r _ u n s i io irq sirq st _ < /proc/stat
total=$((u + n + s + i + io + irq + sirq + st))
idle=$((i))
iowait=$((io))
compute=$((u + n + s + irq + sirq + st))

# Average CPU Core Frequency
freq_sum=0; freq_cnt=0
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
  if [ -f "$f" ]; then
    v=$(cat "$f" 2>/dev/null || echo 0)
    freq_sum=$((freq_sum + v))
    freq_cnt=$((freq_cnt + 1))
  fi
done
avg_freq_mhz=0
[ "$freq_cnt" -gt 0 ] && avg_freq_mhz=$((freq_sum / freq_cnt / 1000))

# Memory & Swap
mem_total=0; mem_avail=0; swap_total=0; swap_free=0
while read -r k v _; do
  case "$k" in
    MemTotal:) mem_total=$v ;;
    MemAvailable:) mem_avail=$v ;;
    SwapTotal:) swap_total=$v ;;
    SwapFree:) swap_free=$v ;;
  esac
done < /proc/meminfo

# GPU (AMD card1 or dynamically detected)
gpu_busy=0; vcn_busy=0; vram_used=0; vram_tot=0; gtt_used=0; gtt_tot=0
for dev in /sys/class/drm/card*/device; do
  if [ -f "$dev/gpu_busy_percent" ]; then
    gpu_busy=$(cat "$dev/gpu_busy_percent" 2>/dev/null || echo 0)
    [ -f "$dev/vcn_busy_percent" ] && vcn_busy=$(cat "$dev/vcn_busy_percent" 2>/dev/null || echo 0)
    [ -f "$dev/mem_info_vram_used" ] && vram_used=$(( $(cat "$dev/mem_info_vram_used" 2>/dev/null || echo 0) / 1048576 ))
    [ -f "$dev/mem_info_vram_total" ] && vram_tot=$(( $(cat "$dev/mem_info_vram_total" 2>/dev/null || echo 0) / 1048576 ))
    [ -f "$dev/mem_info_gtt_used" ] && gtt_used=$(( $(cat "$dev/mem_info_gtt_used" 2>/dev/null || echo 0) / 1048576 ))
    [ -f "$dev/mem_info_gtt_total" ] && gtt_tot=$(( $(cat "$dev/mem_info_gtt_total" 2>/dev/null || echo 0) / 1048576 ))
    break
  fi
done

gpu_temp=0; gpu_power=0
for f in /sys/class/hwmon/hwmon*/temp1_input; do
  hwdir=$(dirname "$f")
  if [ -f "$hwdir/name" ] && grep -q "amdgpu" "$hwdir/name" 2>/dev/null; then
    gpu_temp=$(( $(cat "$f" 2>/dev/null || echo 0) / 1000 ))
    [ -f "$hwdir/power1_input" ] && gpu_power=$(( $(cat "$hwdir/power1_input" 2>/dev/null || echo 0) / 1000000 ))
    break
  fi
done

# CPU Temp (k10temp)
cpu_temp=0
for f in /sys/class/hwmon/hwmon*/temp1_input; do
  hwdir=$(dirname "$f")
  if [ -f "$hwdir/name" ] && grep -qE "k10temp|coretemp|cpu" "$hwdir/name" 2>/dev/null; then
    cpu_temp=$(( $(cat "$f" 2>/dev/null || echo 0) / 1000 ))
    break
  fi
done
if [ "$cpu_temp" -eq 0 ] && [ -f /sys/class/thermal/thermal_zone0/temp ]; then
  cpu_temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0) / 1000 ))
fi

# Storage fields use JSON null when unavailable, never a fabricated zero.
# hwmon temperature and df capacity are independent of uncollected SMART health.
nvme_temp=null
for f in /sys/class/hwmon/hwmon*/temp1_input; do
  hwdir=${f%/*}
  if [[ -r "$hwdir/name" ]] && IFS= read -r sensor_name < "$hwdir/name" && [[ "$sensor_name" == "nvme" ]]; then
    if [[ -r "$f" ]] && IFS= read -r raw_temp < "$f" && [[ "$raw_temp" =~ ^-?[0-9]+$ ]]; then
      magnitude=$((10#${raw_temp#-}))
      [[ "$raw_temp" == -* ]] && magnitude=$((-magnitude))
      if (( magnitude >= -40000 && magnitude <= 150000 )); then
        nvme_temp=$((magnitude / 1000))
      fi
    fi
    break
  fi
done

capacity_json() {
  local path=$1 name=$2 total used available percent
  if read -r total used available percent < <(df -BG -- "$path" 2>/dev/null | awk 'NR==2 {print $2,$3,$4,$5}' | tr -d 'G%') &&
      [[ "$total" =~ ^[0-9]+$ && "$used" =~ ^[0-9]+$ && "$available" =~ ^[0-9]+$ && "$percent" =~ ^[0-9]+$ ]]; then
    # Names are fixed literals from this script, not paths or external metadata.
    printf '{"name":"%s","total":%s,"used":%s,"free":%s,"pct":%s}' "$name" "$total" "$used" "$available" "$percent"
  else
    printf 'null'
  fi
}
root_part=$(capacity_json / 'System Root (/)')
user_part=null
user_media_path=$(find /run/media -maxdepth 2 -name "volume 2" 2>/dev/null | head -n 1 || true)
if [[ -n "$user_media_path" && -d "$user_media_path" ]]; then
  user_part=$(capacity_json "$user_media_path" 'Volume 2')
elif [[ -d /mnt/c ]]; then
  user_part=$(capacity_json /mnt/c 'Windows C:')
fi

# Battery / AC Power
bat_cap=100; bat_status="AC"
if [ -f /sys/class/power_supply/BAT0/capacity ]; then
  bat_cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
  bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "AC")
fi

btop_installed="false"
if command -v btop &>/dev/null; then
  btop_installed="true"
fi

echo "{\"btop_installed\":$btop_installed,\"cpu\":{\"total\":$total,\"idle\":$idle,\"iowait\":$iowait,\"compute\":$compute,\"temp\":$cpu_temp,\"freq_mhz\":$avg_freq_mhz},\"gpu\":{\"util\":$gpu_busy,\"vcn\":$vcn_busy,\"vram_used\":$vram_used,\"vram_tot\":$vram_tot,\"gtt_used\":$gtt_used,\"gtt_tot\":$gtt_tot,\"temp\":$gpu_temp,\"power\":$gpu_power},\"ram\":{\"total\":$((mem_total/1024)),\"avail\":$((mem_avail/1024)),\"used\":$(((mem_total-mem_avail)/1024)),\"swap_total\":$((swap_total/1024)),\"swap_used\":$(((swap_total-swap_free)/1024))},\"storage\":{\"nvme_temp\":$nvme_temp,\"root\":$root_part,\"volume2\":$user_part,\"smart\":{\"state\":\"unavailable\",\"reason\":\"not-collected\"}},\"battery\":{\"pct\":$bat_cap,\"status\":\"$bat_status\"}}"
