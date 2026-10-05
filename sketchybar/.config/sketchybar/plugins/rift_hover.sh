#!/usr/bin/env bash
# Hover handling for Rift workspace items and their popup children.
# Usage: rift_hover.sh <workspace-index> <display-uuid>
# ($NAME = event source, $SENDER = event name.)
#
# - mouse.entered on the workspace item: show its window popup.
# - mouse.entered on a popup child: keepalive (stays open while the pointer
#   moves between item and popup).
# - mouse.exited anywhere: hide shortly after, unless the pointer re-entered
#   in the meantime (checked via the keepalive timestamp).
# - any other event: normal item refresh (delegates to rift.sh).

PARENT="$NAME"
if [[ "$PARENT" == *.win* ]]; then
    PARENT="${PARENT%%.win*}"
fi
FLAG="/tmp/sketchybar_rift_hover_${PARENT}"
COUNT_FILE="${FLAG}.count"

touch_flag() {
    touch "$FLAG"
    # Generation counter: integer wall-clock math races sub-second
    # enter/exit sequences (same-second touch and check reads age 0 and
    # either sticks open or mis-hides), so count enters instead.
    count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    echo $((count + 1)) > "$COUNT_FILE"
}

schedule_hide() {
    # Hide 1.0s later unless the pointer re-entered in the meantime (counter
    # moved). Terminates: each exit schedules at most one check, and checks
    # never reschedule.
    local seen
    seen=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    (
        sleep 1.0
        if [ "$(cat "$COUNT_FILE" 2>/dev/null || echo 0)" = "$seen" ]; then
            NAME="$PARENT" "$CONFIG_DIR/plugins/rift_popup.sh" "$1" "$2" hide
        fi
    ) >/dev/null 2>&1 &
}

case "$SENDER" in
    mouse.entered)
        touch_flag
        if [[ "$NAME" != *.win* ]]; then
            NAME="$PARENT" "$CONFIG_DIR/plugins/rift_popup.sh" "$1" "$2" show
        fi
        ;;
    mouse.exited)
        schedule_hide "$1" "$2"
        ;;
    *)
        exec "$CONFIG_DIR/plugins/rift.sh" "$1" "$2"
        ;;
esac
