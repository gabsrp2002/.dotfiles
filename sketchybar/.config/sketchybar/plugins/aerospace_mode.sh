#!/bin/bash

source "$CONFIG_DIR/colors.sh"


echo "New mode: $MODE" >> $HOME/temp.txt

if [ -z "${MODE+x}" ]; then
    exit
fi

sketchybar --set $NAME label="$MODE"

case "$MODE" in
  main)
    sketchybar --set $NAME background.color=$YELLOW label="$MODE"
    ;;
  service)
    sketchybar --set $NAME background.color=$BLUE label="$MODE"
    ;;
  *)
    sketchybar --set $NAME background.color=$RED label="$MODE"
    ;;
esac
