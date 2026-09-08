#!/usr/bin/env bash
# Fast cached luxury weather fetcher for System Plus Island

CACHE_FILE="/tmp/system_plus_weather_cache.json"
NOW=$(date +%s)

# Return cache if less than 10 minutes old
if [ -f "$CACHE_FILE" ]; then
  MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  if [ $((NOW - MTIME)) -lt 600 ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

RAW=$(curl -s --max-time 3 'wttr.in/?format=%l|%t|%C|%h|%w' 2>/dev/null)

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
  raw_num=$(echo "$temp" | grep -oE '[0-9]+' | head -n 1)
  feels_num=$(( raw_num + 3 ))

  JSON="{\"location\":\"${clean_loc:-New Delhi, India}\",\"temp\":\"${temp:-36°C}\",\"feels_like\":\"${feels_num}°C\",\"condition\":\"${cond:-Clear}\",\"humidity\":\"${humid:-32%}\",\"wind\":\"${wind:-17km/h}\",\"icon\":\"$icon\"}"
  echo "$JSON" > "$CACHE_FILE"
  echo "$JSON"
  exit 0
fi

# Fallback default
if [ -f "$CACHE_FILE" ]; then
  cat "$CACHE_FILE"
else
  echo '{"location":"New Delhi, India","temp":"36°C","feels_like":"39°C","condition":"Haze","humidity":"32%","wind":"17km/h","icon":"󰖑"}'
fi
