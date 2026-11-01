#!/bin/sh

source "$CONFIG_DIR/colors.sh"

DISK_USAGE=$(df -h /System/Volumes/Data | awk 'NR==2 {print $3"/"$2}')

sketchybar --set "${NAME:-disk}" icon="" label="$DISK_USAGE" icon.color="$GREEN"
