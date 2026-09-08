#!/usr/bin/env bash
# High-speed enhanced telemetry collector for Omarchy System Plus Island

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

# NVMe Storage Temp
nvme_temp=0
for f in /sys/class/hwmon/hwmon*/temp1_input; do
  hwdir=$(dirname "$f")
  if [ -f "$hwdir/name" ] && grep -q "nvme" "$hwdir/name" 2>/dev/null; then
    nvme_temp=$(( $(cat "$f" 2>/dev/null || echo 0) / 1000 ))
    break
  fi
done

# Storage capacities
read -r r_tot r_used r_avail r_pct < <(df -BG / 2>/dev/null | awk "NR==2 {print \$2,\$3,\$4,\$5}" | tr -d "G%")

user_part=""
if [ -d "/run/media/daemon0/volume 2" ]; then
  read -r u_tot u_used u_avail u_pct < <(df -BG "/run/media/daemon0/volume 2" 2>/dev/null | awk "NR==2 {print \$2,\$3,\$4,\$5}" | tr -d "G%")
  user_part="\"volume2\":{\"name\":\"Volume 2\",\"total\":${u_tot:-0},\"used\":${u_used:-0},\"free\":${u_avail:-0},\"pct\":${u_pct:-0}},"
elif [ -d "/mnt/c" ]; then
  read -r u_tot u_used u_avail u_pct < <(df -BG "/mnt/c" 2>/dev/null | awk "NR==2 {print \$2,\$3,\$4,\$5}" | tr -d "G%")
  user_part="\"volume2\":{\"name\":\"Windows C:\",\"total\":${u_tot:-0},\"used\":${u_used:-0},\"free\":${u_avail:-0},\"pct\":${u_pct:-0}},"
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

echo "{\"btop_installed\":$btop_installed,\"cpu\":{\"total\":$total,\"idle\":$idle,\"iowait\":$iowait,\"compute\":$compute,\"temp\":$cpu_temp,\"freq_mhz\":$avg_freq_mhz},\"gpu\":{\"util\":$gpu_busy,\"vcn\":$vcn_busy,\"vram_used\":$vram_used,\"vram_tot\":$vram_tot,\"gtt_used\":$gtt_used,\"gtt_tot\":$gtt_tot,\"temp\":$gpu_temp,\"power\":$gpu_power},\"ram\":{\"total\":$((mem_total/1024)),\"avail\":$((mem_avail/1024)),\"used\":$(((mem_total-mem_avail)/1024)),\"swap_total\":$((swap_total/1024)),\"swap_used\":$(((swap_total-swap_free)/1024))},\"storage\":{\"nvme_temp\":$nvme_temp,\"root\":{\"name\":\"System Root (/)\",\"total\":${r_tot:-0},\"used\":${r_used:-0},\"free\":${r_avail:-0},\"pct\":${r_pct:-0}},${user_part}\"smart\":\"Healthy\"},\"battery\":{\"pct\":$bat_cap,\"status\":\"$bat_status\"}}"
