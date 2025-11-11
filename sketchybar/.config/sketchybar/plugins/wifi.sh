#!/bin/bash

source "$CONFIG_DIR/colors.sh"

MAX_CHARS=20

# Get VPN and WiFi info
IS_VPN=$(scutil --nc list | grep Connected)
CURRENT_WIFI="$(ipconfig getsummary en0)"
SSID="$(echo "$CURRENT_WIFI" | grep -o "SSID : .*" | sed 's/^SSID : //' | tail -n 1)"

LABEL="$SSID"

# Check if the string length exceeds the maximum
if [[ ${#LABEL} -gt $MAX_CHARS ]]; then
    # Truncate the string and append "..."
    LABEL="${LABEL:0:((MAX_CHARS - 3))}..."
else
    # Keep the original string if it's within the limit
    LABEL="$LABEL"
fi

should_draw_label=true

# Set icon and color based on connection status
if [[ $IS_VPN = *"Connected"* ]] && [[ $SSID = *"iPhone"* ]]; then
    ICON_COLOR=$GREEN
    ICON=󰴳
elif [[ $IS_VPN = *"Connected"* ]] && [[ -n $SSID ]]; then
    ICON_COLOR=$GREEN
    ICON=󰤪
elif [[ $SSID = *"iPhone"* ]]; then
    ICON_COLOR=$ROSEWATER
    ICON=󰌹
elif [[ -n $SSID ]]; then
    ICON_COLOR=$MAUVE
    ICON=󰤨
else
    ICON_COLOR=$RED
    ICON=󰤮
    should_draw_label=false
fi

if $should_draw_label; then
    sketchybar --set "$NAME" \
        icon="$ICON" \
        icon.color="$ICON_COLOR" \
        icon.padding_right=4 \
        label.drawing="on" \
        label="$LABEL"
else
    sketchybar --set "$NAME" \
        icon="$ICON" \
        icon.color="$ICON_COLOR" \
        icon.padding_right=3 \
        label.drawing="off"
fi
