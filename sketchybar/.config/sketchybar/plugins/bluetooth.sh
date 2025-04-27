#!/bin/bash

# Get Bluetooth power state using system_profiler
BT_STATE=$(system_profiler SPBluetoothDataType | grep -m 1 "State: " | awk '{print $2}')

if [ "$BT_STATE" = "On" ]; then
    ICON=""  # Bluetooth ON icon
else
    ICON="󰂲"  # Bluetooth OFF icon
fi

# Update sketchybar
sketchybar --set $NAME icon="$ICON"
