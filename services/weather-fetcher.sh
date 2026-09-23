#!/usr/bin/env bash
# Fast cached luxury weather fetcher for System Pulse Island
# Hardened against unbounded buffering, injection, and quoting vulnerabilities.
set -euo pipefail

export PATH="/usr/bin:/bin"
export LC_ALL="C"

MAX_RESPONSE_BYTES=2048
FORCE_REFRESH=0

for arg in "$@"; do
  case "$arg" in
    --force|--no-cache)
      FORCE_REFRESH=1
      ;;
  esac
done

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

# Return fresh cache if less than 10 minutes old and not forced
if [ "$FORCE_REFRESH" -eq 0 ] && [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ]; then
  MTIME=$(/usr/bin/stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  if [ $((NOW - MTIME)) -lt 600 ]; then
    /usr/bin/cat "$CACHE_FILE" 2>/dev/null || cat "$CACHE_FILE"
    exit 0
  fi
fi

# Fallback printer function
emit_fallback_and_exit() {
  local exit_code="${1:-1}"
  if [ -f "$CACHE_FILE" ] && [ ! -L "$CACHE_FILE" ]; then
    /usr/bin/cat "$CACHE_FILE" 2>/dev/null || cat "$CACHE_FILE"
  else
    printf '%s\n' '{"location":"New Delhi, India","temp":"36°C","feels_like":"39°C","condition":"Haze","humidity":"32%","wind":"17km/h","icon":"󰖑"}'
  fi
  exit "$exit_code"
}

CURL_BIN="/usr/bin/curl"
[ -x "$CURL_BIN" ] || CURL_BIN="curl"
if ! command -v "$CURL_BIN" >/dev/null 2>&1; then
  echo "Error: curl is required but not found in PATH" >&2
  emit_fallback_and_exit 1
fi

JQ_BIN="/usr/bin/jq"
[ -x "$JQ_BIN" ] || JQ_BIN="jq"
if ! command -v "$JQ_BIN" >/dev/null 2>&1; then
  echo "Error: jq is required but not found in PATH" >&2
  emit_fallback_and_exit 1
fi

HEAD_BIN="/usr/bin/head"
[ -x "$HEAD_BIN" ] || HEAD_BIN="head"

WEATHER_URL="${OMARCHY_WEATHER_URL:-https://wttr.in/?format=%l|%t|%C|%h|%w}"

# Protocol constraint: allow HTTPS (default) or HTTP (for local testing)
CURL_PROTO_ARGS=()
if [[ "$WEATHER_URL" == https://* ]]; then
  CURL_PROTO_ARGS=("--proto" "=https" "--tlsv1.2")
elif [[ "$WEATHER_URL" == http://* ]]; then
  CURL_PROTO_ARGS=("--proto" "=http")
fi

# Stream through head -c to enforce hard byte limit at the network ingestion boundary.
# As soon as (MAX_RESPONSE_BYTES + 1) bytes are received, head exits immediately,
# closing the pipe and causing curl to be terminated via SIGPIPE (exit status 141).
FETCH_STATUS=0
RAW_CAP=$(
  set +e
  "$CURL_BIN" -s --max-time 4 --connect-timeout 2 "${CURL_PROTO_ARGS[@]}" "$WEATHER_URL" | "$HEAD_BIN" -c $((MAX_RESPONSE_BYTES + 1))
  curl_exit=${PIPESTATUS[0]}
  printf 'x'
  exit "$curl_exit"
) || FETCH_STATUS=$?
RAW="${RAW_CAP%x}"

# Enforce rejection of oversized responses
if [ "${#RAW}" -gt "$MAX_RESPONSE_BYTES" ]; then
  echo "Error: Weather response exceeded maximum size limit of ${MAX_RESPONSE_BYTES} bytes" >&2
  emit_fallback_and_exit 1
fi

# Reject curl failures or empty response
if [ "$FETCH_STATUS" -ne 0 ] || [ -z "$RAW" ]; then
  echo "Error: Weather fetch failed or returned empty response (curl status: $FETCH_STATUS)" >&2
  emit_fallback_and_exit 1
fi

# Parse and serialize safely using jq RFC 8259 parser/encoder
JQ_PROGRAM='
def trim: sub("^[ \t\r\n]+"; "") | sub("[ \t\r\n]+$"; "");

($raw | split("|")) as $parts
| if ($parts | length) < 5 then
    error("Invalid format: expected 5 pipe-delimited fields")
  else
    ($parts[0] | trim) as $loc
    | ($parts[1] | gsub("[+ ]"; "") | trim) as $temp
    | ($parts[2] | trim) as $cond
    | ($parts[3] | trim) as $humid
    | ($parts[4] | trim) as $wind
    | (
        if ($loc | contains(",")) then
          ($loc | split(",")) as $cparts
          | ($cparts[0] | trim) as $city
          | ($cparts[-1] | trim) as $ctry
          | (if $ctry == "IN" then "India"
             elif $ctry == "US" then "United States"
             elif $ctry == "GB" then "United Kingdom"
             else $ctry end) as $ctry_clean
          | "\($city), \($ctry_clean)"
        else
          $loc
        end
      ) as $clean_loc
    | (
        if ($cond | test("Sun|Clear"; "i")) then "󰖙"
        elif ($cond | test("Partly|Cloud"; "i")) then "󰖕"
        elif ($cond | test("Overcast"; "i")) then "󰖐"
        elif ($cond | test("Rain|Drizzle|Shower"; "i")) then "󰖗"
        elif ($cond | test("Thunder|Storm"; "i")) then "󰖓"
        elif ($cond | test("Snow"; "i")) then "󰖘"
        elif ($cond | test("Haze|Fog|Mist"; "i")) then "󰖑"
        else "󰖐"
        end
      ) as $icon
    | (
        ([$temp | scan("-?[0-9]+")] | first // "36") | tonumber
      ) as $raw_num
    | ($raw_num + 3) as $feels_num
    | {
        location: (if $clean_loc != "" then $clean_loc else "New Delhi, India" end),
        temp: (if $temp != "" then $temp else "36°C" end),
        feels_like: "\($feels_num)°C",
        condition: (if $cond != "" then $cond else "Clear" end),
        humidity: (if $humid != "" then $humid else "32%" end),
        wind: (if $wind != "" then $wind else "17km/h" end),
        icon: $icon
      }
  end
'

JSON=""
JQ_STATUS=0
JSON=$("$JQ_BIN" -n -c --arg raw "$RAW" "$JQ_PROGRAM" 2>/dev/null) || JQ_STATUS=$?

if [ "$JQ_STATUS" -ne 0 ] || [ -z "$JSON" ]; then
  echo "Error: Failed to parse weather response into valid JSON" >&2
  emit_fallback_and_exit 1
fi

# Atomic write to private cache using unpredictable temporary file
[ -L "$CACHE_FILE" ] && rm -f "$CACHE_FILE"
TMP_CACHE=$(mktemp -p "$CACHE_DIR" weather_cache.tmp.XXXXXX 2>/dev/null || echo "")
if [ -n "$TMP_CACHE" ]; then
  printf '%s\n' "$JSON" > "$TMP_CACHE"
  chmod 600 "$TMP_CACHE" 2>/dev/null || true
  mv -f "$TMP_CACHE" "$CACHE_FILE"
fi

printf '%s\n' "$JSON"
exit 0
