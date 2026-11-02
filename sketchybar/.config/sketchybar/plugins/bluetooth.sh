#!/bin/bash

# Debounce burst notifications from com.apple.bluetooth.status
DEBOUNCE_FILE="/tmp/sketchybar_bt_last"
PENDING_FILE="/tmp/sketchybar_bt_pending"
NOW=$(date +%s)
LAST=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)

if [ "${1:-}" != "--trailing" ]; then
    if [ "$SENDER" = "bluetooth_update" ] && [ $((NOW - LAST)) -lt 2 ]; then
        if [ ! -f "$PENDING_FILE" ]; then
            touch "$PENDING_FILE"
            (
                sleep 1
                rm -f "$PENDING_FILE"
                CONFIG_DIR="$CONFIG_DIR" NAME="${NAME:-bluetooth}" "$0" --trailing
            ) >/dev/null 2>&1 &
        fi
        exit 0
    fi
fi
echo "$NOW" > "$DEBOUNCE_FILE"

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
    else
        ICON="󰂲"
    fi
fi

sketchybar --set "${NAME:-bluetooth}" icon="$ICON"
