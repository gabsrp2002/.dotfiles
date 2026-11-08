#!/bin/sh

source "$CONFIG_DIR/colors.sh"

BATT_INFO="$(pmset -g batt)"
PERCENTAGE="$(printf '%s\n' "$BATT_INFO" | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(printf '%s\n' "$BATT_INFO" | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[0-9]|100) ICON=""
  ;;
  [6-8][0-9]) ICON=""
  ;;
  [3-5][0-9]) ICON=""
  ;;
  [1-2][0-9]) ICON=""
  ;;
  *) ICON=""
esac

case "${PERCENTAGE}" in
  [6-9][0-9]|100) ICON_COLOR=$GREEN
  ;;
  [3-5][0-9]) ICON_COLOR=$YELLOW
  ;;
  *) ICON_COLOR=$RED
esac

if [[ "$CHARGING" != "" ]]; then
  ICON=""
  ICON_COLOR=$YELLOW
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" icon.color="$ICON_COLOR"
