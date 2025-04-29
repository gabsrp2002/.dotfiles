#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Path to store previous stats
STATS_FILE="$HOME/.wifi_stats"

# Get VPN and WiFi info
IS_VPN=$(scutil --nc list | grep Connected)
CURRENT_WIFI="$(ipconfig getsummary en0)"
IP_ADDRESS="$(echo "$CURRENT_WIFI" | grep -o "ciaddr = .*" | sed 's/^ciaddr = //')"
SSID="$(echo "$CURRENT_WIFI" | grep -o "SSID : .*" | sed 's/^SSID : //' | tail -n 1)"

# Get network interface (usually en0 for WiFi)
INTERFACE="en0"

# Get current timestamp and network stats
CURRENT_TIME=$(date +%s)
NET_STATS=$(netstat -ib -I "$INTERFACE" | grep -E "Link#[0-9]+")
DOWNLOAD_BYTES=$(echo "$NET_STATS" | awk '{print $7}' | head -n 1)
UPLOAD_BYTES=$(echo "$NET_STATS" | awk '{print $10}' | head -n 1)


# Validate stats
if [ -z "$DOWNLOAD_BYTES" ] || [ -z "$UPLOAD_BYTES" ] || [ "$DOWNLOAD_BYTES" -eq 0 ] || [ "$UPLOAD_BYTES" -eq 0 ]; then
    DOWNLOAD_SPEED=""
    UPLOAD_SPEED=""
else
    # Read previous stats if available
    if [ -f "$STATS_FILE" ]; then
        read PREV_TIME PREV_DOWNLOAD PREV_UPLOAD < "$STATS_FILE"
    else
        PREV_TIME=$CURRENT_TIME
        PREV_DOWNLOAD=$DOWNLOAD_BYTES
        PREV_UPLOAD=$UPLOAD_BYTES
    fi

    # Detect counter reset (e.g., interface restart)
    if [ "$DOWNLOAD_BYTES" -lt "$PREV_DOWNLOAD" ] || [ "$UPLOAD_BYTES" -lt "$PREV_UPLOAD" ]; then
        PREV_DOWNLOAD=$DOWNLOAD_BYTES
        PREV_UPLOAD=$UPLOAD_BYTES
        PREV_TIME=$CURRENT_TIME
    fi

    # Calculate time difference and byte differences
    TIME_DIFF=$((CURRENT_TIME - PREV_TIME))
    if [ $TIME_DIFF -eq 0 ]; then
        TIME_DIFF=1 # Prevent division by zero
    fi
    DOWNLOAD_DIFF=$((DOWNLOAD_BYTES - PREV_DOWNLOAD))
    UPLOAD_DIFF=$((UPLOAD_BYTES - PREV_UPLOAD))

    # Calculate speeds in bytes per second
    DOWNLOAD_SPEED=$((DOWNLOAD_DIFF / TIME_DIFF))
    UPLOAD_SPEED=$((UPLOAD_DIFF / TIME_DIFF))


    # Save current stats for next run
    echo "$CURRENT_TIME $DOWNLOAD_BYTES $UPLOAD_BYTES" > "$STATS_FILE"

    # Convert bytes to human-readable format
    format_speed() {
        local icon=$2
        local bytes=$1
        if [ $bytes -lt 0 ]; then
            bytes=0 # Handle negative diffs
        fi
        if [ $bytes -lt 1024 ]; then
            printf "%6sB/s $icon\n" "$bytes"
        elif [ $bytes -lt 1048576 ]; then
            printf "%5sKB/s $icon\n" "$((bytes / 1024))"
        else
            # For MB, we keep one decimal, so we'll format it separately
            local mb=$(bc <<< "scale=1; $bytes/1048576")
            printf "%5sMB/s $icon\n" "$mb"
        fi
    }

    DOWNLOAD_SPEED=$(format_speed $DOWNLOAD_SPEED "↓")
    UPLOAD_SPEED=$(format_speed $UPLOAD_SPEED "↑")
fi

LABEL="$SSID | $DOWNLOAD_SPEED $UPLOAD_SPEED"

if [ -z "$DOWNLOAD_SPEED" ] || [ -z "$UPLOAD_SPEED" ]; then
    LABEL="$SSID"
fi

should_draw_label=true

# Set icon and color based on connection status
if [[ $IS_VPN = *"Connected"* ]]; then
    ICON_COLOR=$GREEN
    ICON=􀎡
elif [[ $SSID = "iPhone do Gabriel" ]]; then
    ICON_COLOR=$ROSEWATER
    ICON=􀉤
elif [[ -n $SSID ]]; then
    ICON_COLOR=$MAUVE
    ICON=􀐿
else
    ICON_COLOR=$RED
    ICON=􀐾
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
        icon.padding_right=7 \
        label.drawing="off"
fi
