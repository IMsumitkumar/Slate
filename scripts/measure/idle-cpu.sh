#!/bin/bash
# Samples Slate's CPU% while idle. A proxy for the Activity Monitor "Energy
# Impact" check in BROWSER_SPEC.md Section 5, which needs a real GUI session.
set -uo pipefail
APP="$1"; MINUTES="${2:-5}"
pkill -x Slate 2>/dev/null; sleep 3
open -a "$APP"; sleep 20   # let start-up work settle before sampling
PID=$(pgrep -x Slate | head -1)
[[ -n "$PID" ]] || { echo "not running"; exit 1; }
echo "sampling pid $PID for ${MINUTES} min"
END=$(( $(date +%s) + MINUTES*60 ))
SUM=0; N=0; MAX=0
while [[ $(date +%s) -lt $END ]]; do
    kill -0 "$PID" 2>/dev/null || { echo "exited"; break; }
    C=$(ps -o %cpu= -p "$PID" | tr -d ' ')
    SUM=$(echo "$SUM + $C" | bc); N=$((N+1))
    (( $(echo "$C > $MAX" | bc) )) && MAX=$C
    sleep 10
done
[[ $N -gt 0 ]] && printf "samples=%d mean_cpu=%.2f%% max_cpu=%.2f%%\n" "$N" "$(echo "$SUM/$N" | bc -l)" "$MAX"
pkill -x Slate 2>/dev/null
