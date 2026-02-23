#!/bin/sh

source "$CONFIG_DIR/colors.sh"

DISK_INFO=$(df -h /System/Volumes/Data | tail -1)
TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
USED=$(echo "$DISK_INFO" | awk '{print $3}')

sketchybar --set "$NAME" icon="" label="${USED}/${TOTAL}" icon.color="$GREEN"
