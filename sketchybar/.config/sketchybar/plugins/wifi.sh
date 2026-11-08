#!/bin/bash

case "$SENDER" in
    mouse.entered)
        exec "$CONFIG_DIR/plugins/click_wifi.sh" show
        ;;
    mouse.exited)
        exec "$CONFIG_DIR/plugins/click_wifi.sh" hover_exit
        ;;
    mouse.scrolled)
        exec "$CONFIG_DIR/plugins/click_wifi.sh" scroll
        ;;
esac

source "$CONFIG_DIR/colors.sh"

MAX_CHARS=20

# Fast VPN check and WiFi summary extraction
IS_VPN=$(scutil --nc list 2>/dev/null | grep -q Connected && echo 1 || echo 0)
CURRENT_WIFI="$(ipconfig getsummary en0 2>/dev/null)"
SSID=$(echo "$CURRENT_WIFI" | awk -F': ' '/  SSID : / {print $2; exit}')

LABEL="$SSID"

# Check if the string length exceeds the maximum
if [[ ${#LABEL} -gt $MAX_CHARS ]]; then
    LABEL="${LABEL:0:((MAX_CHARS - 3))}..."
fi

should_draw_label=true

# Set icon and color based on connection status
if [[ $IS_VPN -eq 1 ]] && [[ $SSID = *"iPhone"* ]]; then
    ICON_COLOR=$GREEN
    ICON=󰴳
elif [[ $IS_VPN -eq 1 ]] && [[ -n $SSID ]]; then
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
    sketchybar --set "${NAME:-wifi}" \
        icon="$ICON" \
        icon.color="$ICON_COLOR" \
        icon.padding_right=4 \
        label.drawing="on" \
        label="$LABEL"
else
    sketchybar --set "${NAME:-wifi}" \
        icon="$ICON" \
        icon.color="$ICON_COLOR" \
        icon.padding_right=3 \
        label.drawing="off"
fi
