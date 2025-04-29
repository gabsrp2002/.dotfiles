#!/bin/bash

source "$CONFIG_DIR/colors.sh"

lock() {
  sketchybar --bar y_offset=-30 \
                   margin=-200
}

unlock() {
  sketchybar --animate sin 15 \
             --bar y_offset=-30 \
                   y_offset=0 \
                   margin=-200 \
                   margin=0
}

case "$SENDER" in
  "lock") lock
  ;;
  "unlock") unlock
  ;;
esac
