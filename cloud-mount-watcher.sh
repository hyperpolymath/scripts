#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# cloud-mount-watcher.sh - Detects failed rclone cloud mounts and auto-remounts
# Checks: mount presence, FUSE responsiveness, rclone process health
# Runs via systemd timer every 60 seconds
#
# Notification behaviour:
#   - Repair SUCCESS: persistent notification (user must dismiss)
#   - Repair FAILURE: critical persistent notification, auto-dismissed when recovered
#   - Healthy after prior failure: auto-clears the failure notification

set -euo pipefail

readonly LOG_DIR="${HOME}/.local/share/dependability"
readonly LOG_FILE="${LOG_DIR}/cloud-mount-watcher.log"
readonly FAIL_STATE_DIR="${LOG_DIR}/cloud-watcher-failures"
mkdir -p "$LOG_DIR" "$FAIL_STATE_DIR"

log() {
    local level="$1"; shift
    printf '%s [CLOUD-WATCHER] [%s] %s\n' "$(date -Iseconds)" "$level" "$*" >> "$LOG_FILE"
}

# Send a desktop notification with a stable replace-id so we can update/dismiss it.
# Usage: send_notify urgency replace_tag title body
send_notify() {
    local urgency="$1" tag="$2" title="$3" body="$4"
    if command -v notify-send &>/dev/null; then
        # --hint string:x-canonical-private-synchronous:TAG  keeps a single
        # replaceable slot per TAG so repeated alerts don't spam. The
        # "resident" hint asks the DE to keep the notification visible until
        # the user acts on it (supported by GNOME 45+, KDE Plasma 6).
        notify-send \
            -u "$urgency" \
            -h "string:x-canonical-private-synchronous:cloud-watcher-${tag}" \
            -h "boolean:resident:true" \
            "$title" "$body" 2>/dev/null || true
    fi
}

# Close/replace a notification by sending a minimal "resolved" update.
# Usage: clear_notify tag
clear_notify() {
    local tag="$1"
    if command -v notify-send &>/dev/null; then
        # Replace the persistent notification with a transient "resolved" one
        # that auto-expires after 5 seconds (5000 ms).
        notify-send \
            -u normal \
            -t 5000 \
            -h "string:x-canonical-private-synchronous:cloud-watcher-${tag}" \
            "Cloud Mount Watcher" "${tag} recovered — mount is healthy" 2>/dev/null || true
    fi
}

# Rotate log if > 2MB
if [[ -f "$LOG_FILE" ]] && (( $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) > 2097152 )); then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    log "INFO" "Log rotated"
fi

# Cloud mount definitions: remote_name:mount_point:service_name
declare -a MOUNTS=(
    "gdrive:/var$HOME/Cloud/GoogleDrive:rclone-gdrive.service"
    "onedrive:/var$HOME/Cloud/OneDrive:rclone-onedrive.service"
    "dropbox:/var$HOME/Cloud/Dropbox:rclone-dropbox.service"
)

repaired=0
checked=0

for entry in "${MOUNTS[@]}"; do
    IFS=':' read -r remote mount_point service <<< "$entry"
    checked=$((checked + 1))
    needs_repair=false
    reason=""

    # Check 1: Is the service supposed to be enabled?
    if ! systemctl --user is-enabled "$service" &>/dev/null; then
        # Service isn't enabled, skip it (user doesn't want it)
        continue
    fi

    # Check 2: Is it mounted at all?
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        needs_repair=true
        reason="not mounted"
    fi

    # Check 3: If mounted, is the FUSE mount responsive? (timeout after 5s)
    if [[ "$needs_repair" == "false" ]]; then
        if ! timeout 5 ls "$mount_point" &>/dev/null; then
            needs_repair=true
            reason="mount unresponsive (stale FUSE)"
        fi
    fi

    # Check 4: Is the rclone process actually running for this mount?
    if [[ "$needs_repair" == "false" ]]; then
        if ! systemctl --user is-active "$service" &>/dev/null; then
            needs_repair=true
            reason="service not active"
        fi
    fi

    # BACKOFF & LOAD PROTECTION
    backoff_file="${FAIL_STATE_DIR}/${remote}.backoff"
    
    if [[ "$needs_repair" == "true" ]]; then
        # Check system load - don't add fuel to the fire
        load=$(awk '{print int($1)}' /proc/loadavg)
        if (( load > 4 )); then
            log "WARN" "System load high (${load}), deferring repair for ${remote}"
            continue
        fi

        # Check backoff counter
        failures=$(cat "$backoff_file" 2>/dev/null || echo 0)
        failures=$((failures + 1))
        echo "$failures" > "$backoff_file"

        # Exponential backoff: 1, 2, 4, 8, 16...
        # If failures=3, wait until cycle is multiple of 4 (2^2)
        # If failures=5, wait until cycle is multiple of 16 (2^4)
        backoff_limit=6 # Max backoff 2^6 = 64 cycles (~1 hour)
        current_backoff=$(( failures > backoff_limit ? backoff_limit : failures ))
        wait_cycles=$(( 2 ** (current_backoff - 1) ))
        
        # We use the global count file as a tick counter
        global_tick=$(cat "${LOG_DIR}/.cloud-watcher-count" 2>/dev/null || echo 0)
        
        # If we are NOT on a retry tick, skip
        if (( global_tick % wait_cycles != 0 )); then
            log "INFO" "${remote} failed, backing off (attempt ${failures}, waiting for next window)"
            continue
        fi

        log "ALERT" "${remote} mount failed: ${reason} — attempting repair (attempt ${failures})"

        # Mark this mount as having an outstanding failure
        echo "$reason" > "${FAIL_STATE_DIR}/${remote}"

        # Send persistent failure notification (stays until dismissed or cleared)
        send_notify "critical" "$remote" \
            "Cloud Mount Watcher" \
            "${remote} mount failed: ${reason} — attempting repair..."

        # Step 1: Clean up stale FUSE mount if present
        if mountpoint -q "$mount_point" 2>/dev/null; then
            fusermount -u "$mount_point" 2>/dev/null || true
            sleep 1
        fi

        # Step 2: Force-unmount if still stuck
        if mountpoint -q "$mount_point" 2>/dev/null; then
            fusermount -uz "$mount_point" 2>/dev/null || true
            sleep 1
        fi

        # Step 3: Reset failed state and restart the service
        systemctl --user reset-failed "$service" 2>/dev/null || true
        if systemctl --user restart "$service" 2>/dev/null; then
            # Wait for the mount to come up (rclone has a 5s sleep + mount time)
            sleep 8
            if mountpoint -q "$mount_point" 2>/dev/null; then
                log "INFO" "${remote} mount repaired successfully"
                repaired=$((repaired + 1))

                # Clear the failure state
                rm -f "${FAIL_STATE_DIR}/${remote}"

                # Persistent success notification (user must dismiss)
                send_notify "normal" "$remote" \
                    "Cloud Mount Watcher" \
                    "${remote} mount REPAIRED successfully (was: ${reason})"
            else
                log "CRIT" "${remote} mount repair FAILED — service restarted but mount not present"

                # Update the failure notification to show repair failed
                send_notify "critical" "$remote" \
                    "Cloud Mount Watcher" \
                    "${remote} mount repair FAILED — will retry next cycle (was: ${reason})"
            fi
        else
            log "CRIT" "${remote} mount repair FAILED — could not restart ${service}"

            send_notify "critical" "$remote" \
                "Cloud Mount Watcher" \
                "${remote} repair FAILED — could not restart ${service}"
        fi
    else
        # Mount is healthy — if there was a prior failure, clear its notification
        if [[ -f "${FAIL_STATE_DIR}/${remote}" ]]; then
            log "INFO" "${remote} recovered from previous failure"
            rm -f "${FAIL_STATE_DIR}/${remote}"
            rm -f "${FAIL_STATE_DIR}/${remote}.backoff" # Reset backoff
            clear_notify "$remote"
        fi
    fi
done

if (( repaired > 0 )); then
    log "INFO" "Watcher check complete: ${repaired}/${checked} mount(s) repaired"
elif (( checked > 0 )); then
    # Only log periodic health confirmations every ~10 minutes (every 10th check)
    count_file="${LOG_DIR}/.cloud-watcher-count"
    count=$(cat "$count_file" 2>/dev/null || echo 0)
    count=$((count + 1))
    echo "$count" > "$count_file"
    if (( count % 10 == 0 )); then
        log "INFO" "All ${checked} cloud mount(s) healthy"
    fi
fi
