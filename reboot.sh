#!/usr/bin/env bash
# scripts/reboot.sh — Wrapper to track reboot/shutdown reason before execution
# Usage:
#   alias reboot='bash /var$REPOS_DIR/scripts/reboot.sh'
#   alias shutdown='bash /var$REPOS_DIR/scripts/reboot.sh --shutdown'

DENO_BIN="/home/hyper/.deno/bin/deno"
TRACKER_TS="/var$REPOS_DIR/scripts/reboot-tracker.ts"

# Parse args
IS_SHUTDOWN=false
for arg in "$@"; do
    if [[ "$arg" == "--shutdown" ]]; then
        IS_SHUTDOWN=true
    fi
done

# Ensure log directory exists
mkdir -p /var$REPOS_DIR/monitoring/reboot-tracker/logs

if [ -f "$TRACKER_TS" ]; then
    if [[ "$IS_SHUTDOWN" == true ]]; then
        "$DENO_BIN" run --allow-read --allow-write --allow-env --allow-run "$TRACKER_TS" --shutdown
    else
        "$DENO_BIN" run --allow-read --allow-write --allow-env --allow-run "$TRACKER_TS"
    fi
else
    echo "Error: Tracker script not found at $TRACKER_TS"
    read -p "Continue with raw command anyway? (y/N): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        if [[ "$IS_SHUTDOWN" == true ]]; then
            sudo /usr/sbin/shutdown
        else
            sudo /usr/sbin/reboot
        fi
    else
        echo "Aborted."
        exit 1
    fi
fi
