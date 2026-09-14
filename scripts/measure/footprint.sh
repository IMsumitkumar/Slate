#!/bin/bash
# Measures Slate's cold launch time and idle memory footprint.
#
# Memory is phys_footprint (what Activity Monitor calls "Memory"), summed over
# the app process and the WebKit XPC helpers this launch spawned. WebKit helpers
# are launchd children rather than app children, so they are identified by
# diffing a PID snapshot taken before launch against one taken after.
set -uo pipefail

APP="${1:?usage: measure.sh <app-bundle> [settle-seconds] [label]}"
SETTLE="${2:-30}"
LABEL="${3:-run}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Build the launch probe on demand so this script works from a clean checkout.
PROBE="${SLATE_LAUNCH_PROBE:-${TMPDIR:-/tmp}/slate-launchtime}"
if [[ ! -x "$PROBE" || "$HERE/launchtime.swift" -nt "$PROBE" ]]; then
    swiftc -O "$HERE/launchtime.swift" -o "$PROBE" || { echo "failed to build launch probe" >&2; exit 1; }
fi

webkit_pids() { pgrep -f 'com\.apple\.WebKit\.(WebContent|Networking|GPU)' 2>/dev/null | sort -n; }
fp_mb() { footprint -p "$1" 2>/dev/null | awk '/phys_footprint:/ {print $2, $3}' | tail -1; }
fp_bytes() {
    local v unit
    read -r v unit <<< "$(fp_mb "$1")"
    [[ -z "${v:-}" ]] && { echo 0; return; }
    case "$unit" in
        KB) echo "$v * 1024" | bc ;;
        MB) echo "$v * 1048576" | bc ;;
        GB) echo "$v * 1073741824" | bc ;;
        *)  echo "$v" ;;
    esac
}

BEFORE=$(webkit_pids)
LINE=$("$PROBE" "$APP")
PID=$(echo "$LINE" | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
MS=$(echo "$LINE" | sed -n 's/.*window_ms=\([0-9.]*\).*/\1/p')

echo "== $LABEL =="
echo "cold_launch_to_window_ms: ${MS:-TIMEOUT}"
[[ -n "$PID" ]] || { echo "no pid"; exit 1; }

sleep "$SETTLE"
kill -0 "$PID" 2>/dev/null || { echo "app exited during settle"; exit 1; }

AFTER=$(webkit_pids)
NEW=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER"))

APP_B=$(fp_bytes "$PID")
TOTAL_B=$APP_B
printf "app                 %8.1f MB\n" "$(echo "$APP_B/1048576" | bc -l)"
for p in $NEW; do
    kill -0 "$p" 2>/dev/null || continue
    B=$(fp_bytes "$p"); [[ "$B" == "0" ]] && continue
    C=$(ps -o comm= -p "$p" 2>/dev/null | sed 's|.*/||')
    printf "  %-16s  %8.1f MB  (pid %s)\n" "$C" "$(echo "$B/1048576" | bc -l)" "$p"
    TOTAL_B=$(echo "$TOTAL_B + $B" | bc)
done
printf "TOTAL               %8.1f MB\n" "$(echo "$TOTAL_B/1048576" | bc -l)"
echo "pid=$PID"
