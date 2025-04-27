#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/aerospace.sh

# Check if it's the initialization
if [ -z "${FOCUSED_WORKSPACE+x}" ]; then
    echo "Not set" >> ~/temp/temp$1.txt
    exit
fi

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME background.color=0xffB4BEFE label.color=0xff1E1E2E
else
    sketchybar --set $NAME background.color=0xff313244 label.color=0xffA6ADC8
fi

was_removed=true
for sid in $(aerospace list-workspaces --all); do
    if [ "$1" = "$sid" ]; then
        was_removed=false
        break
    fi
done

if $was_removed; then
    sketchybar --remove $NAME
fi
