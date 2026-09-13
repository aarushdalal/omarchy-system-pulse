#!/usr/bin/env bash
# Fast cached luxury weather fetcher for System Pulse Island
set -euo pipefail

export PATH="/usr/bin:/bin"
export LC_ALL="C"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy"
mkdir -p "$CACHE_DIR" 2>/dev/null || true
chmod 700 "$CACHE_DIR" 2>/dev/null || true

# Validate cache directory is private and not a symlink
if [ -L "$CACHE_DIR" ] || [ ! -d "$CACHE_DIR" ]; then
  CACHE_DIR="/run/user/$(id -u)/omarchy"
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
  chmod 700 "$CACHE_DIR" 2>/dev/null || true
fi

CACHE_FILE="$CACHE_DIR/weather_cache.json"
NOW=$(/usr/bin/date +%s 2>/dev/null || date +%s)

# Return cache if less than 10 minutes old and not a symlink
if [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ]; then
  MTIME=$(/usr/bin/stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  if [ $((NOW - MTIME)) -lt 600 ]; then
    /usr/bin/cat "$CACHE_FILE" 2>/dev/null || cat "$CACHE_FILE"
    exit 0
  fi
fi

CURL_BIN="/usr/bin/curl"
[ -x "$CURL_BIN" ] || CURL_BIN="curl"

RAW=$("$CURL_BIN" -s --max-time 3 'wttr.in/?format=%l|%t|%C|%h|%w' 2>/dev/null || true)

if [ -n "$RAW" ] && [[ "$RAW" == *"|"* ]]; then
  IFS='|' read -r loc temp cond humid wind <<< "$RAW"
  loc=$(echo "$loc" | xargs)
  temp=$(echo "$temp" | tr -d '+ ' | xargs)
  cond=$(echo "$cond" | xargs)
  humid=$(echo "$humid" | xargs)
  wind=$(echo "$wind" | xargs)

  # Clean location name
  clean_loc="$loc"
  if [[ "$loc" == *","* ]]; then
    city=$(echo "$loc" | cut -d',' -f1 | xargs)
    country=$(echo "$loc" | awk -F',' '{print $NF}' | xargs)
    [ "$country" == "IN" ] && country="India"
    [ "$country" == "US" ] && country="United States"
    [ "$country" == "GB" ] && country="United Kingdom"
    clean_loc="$city, $country"
  fi

  icon="󰖐"
  case "$cond" in
    *Sun*|*Clear*) icon="󰖙" ;;
    *Partly*|*Cloud*) icon="󰖕" ;;
    *Overcast*) icon="󰖐" ;;
    *Rain*|*Drizzle*|*Shower*) icon="󰖗" ;;
    *Thunder*|*Storm*) icon="󰖓" ;;
    *Snow*) icon="󰖘" ;;
    *Haze*|*Fog*|*Mist*) icon="󰖑" ;;
  esac

  # Estimate feels-like temp
  raw_num=$(echo "$temp" | grep -oE '[0-9]+' | head -n 1 || echo 36)
  feels_num=$(( raw_num + 3 ))

  JSON="{\"location\":\"${clean_loc:-New Delhi, India}\",\"temp\":\"${temp:-36°C}\",\"feels_like\":\"${feels_num}°C\",\"condition\":\"${cond:-Clear}\",\"humidity\":\"${humid:-32%}\",\"wind\":\"${wind:-17km/h}\",\"icon\":\"$icon\"}"

  # Atomic no-follow write
  [ -L "$CACHE_FILE" ] && rm -f "$CACHE_FILE"
  TMP_CACHE="${CACHE_FILE}.tmp.$$"
  echo "$JSON" > "$TMP_CACHE"
  chmod 600 "$TMP_CACHE" 2>/dev/null || true
  mv -f "$TMP_CACHE" "$CACHE_FILE"
  echo "$JSON"
  exit 0
fi

# Fallback default
if [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ]; then
  /usr/bin/cat "$CACHE_FILE" 2>/dev/null || cat "$CACHE_FILE"
else
  echo '{"location":"New Delhi, India","temp":"36°C","feels_like":"39°C","condition":"Haze","humidity":"32%","wind":"17km/h","icon":"󰖑"}'
fi
