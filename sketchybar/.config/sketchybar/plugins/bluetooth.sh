#!/bin/bash

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
