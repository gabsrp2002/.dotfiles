#!/bin/bash
# Rift binding-mode indicator. Triggered by rift_mode_change (subscribed via
# run_on_start: binding_mode_changed). Reads live state via query so it never
# depends on event payload shapes.

source "$CONFIG_DIR/colors.sh"

MODE=$(rift-cli query binding-mode 2>/dev/null | jq -r '. // empty')
[ -z "$MODE" ] && exit 0

sketchybar --set "$NAME" label="$MODE"

case "$MODE" in
  default)
    sketchybar --set "$NAME" background.color=$GREEN
    ;;
  service)
    sketchybar --set "$NAME" background.color=$RED
    ;;
  *)
    sketchybar --set "$NAME" background.color=$PINK
    ;;
esac
