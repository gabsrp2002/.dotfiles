#!/bin/bash

source "$CONFIG_DIR/colors.sh"


echo "New mode: $MODE" >> $HOME/temp.txt

if [ -z "${MODE+x}" ]; then
    exit
fi

sketchybar --set $NAME label="$MODE"

# If a workspace was focused, then update space coloring
if [ "$MODE" = "main" ]; then
    sketchybar --set $NAME background.color=$YELLOW label="$MODE"
elif [ "$MODE" = "service" ]; then
    sketchybar --set $NAME background.color=$BLUE label="$MODE"
else
    sketchybar --set $NAME background.color=$RED label="$MODE"
fi

