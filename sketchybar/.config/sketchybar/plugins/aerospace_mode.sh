#!/bin/bash

source "$CONFIG_DIR/colors.sh"


if [ -z "${MODE+x}" ]; then
    exit
fi

sketchybar --set $NAME label="$MODE"

case "$MODE" in
  main)
    sketchybar --set $NAME background.color=$GREEN label="$MODE"
    ;;
  service)
    sketchybar --set $NAME background.color=$RED label="$MODE"
    ;;
  *)
    sketchybar --set $NAME background.color=$PINK label="$MODE"
    ;;
esac
