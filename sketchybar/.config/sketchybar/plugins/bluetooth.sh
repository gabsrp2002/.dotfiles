#!/bin/bash

# Prevent concurrent runs during rapid notification bursts
LOCKDIR="/tmp/sketchybar_bt.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
    # Auto-reclaim orphaned lock older than 5 seconds
    if [ $(($(date +%s) - $(stat -f %m "$LOCKDIR" 2>/dev/null || echo 0))) -gt 5 ]; then
        rm -rf "$LOCKDIR"
    fi
    exit 0
fi
trap 'rm -rf "$LOCKDIR"' EXIT

STATE_FILE="/tmp/sketchybar_bt_state"
LAST_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "")

# Fast Bluetooth power state query using blueutil (avoids slow system_profiler)
if command -v blueutil >/dev/null 2>&1; then
    BT_STATE=$(blueutil --power 2>/dev/null)
    if [ "$BT_STATE" = "1" ]; then
        ICON=""
    else
        ICON="󰂲"
    fi
else
    BT_STATE=$(system_profiler SPBluetoothDataType 2>/dev/null | grep -m 1 "State: " | awk '{print $2}')
    if [ "$BT_STATE" = "On" ]; then
        ICON=""
        BT_STATE="1"
    else
        ICON="󰂲"
        BT_STATE="0"
    fi
fi

# Ignore routine background status cycles if power hasn't changed
if [ -n "$LAST_STATE" ] && [ "$BT_STATE" = "$LAST_STATE" ] && [ "$SENDER" = "bluetooth_update" ]; then
    exit 0
fi

echo "$BT_STATE" > "$STATE_FILE"

sketchybar --set "${NAME:-bluetooth}" icon="$ICON"
