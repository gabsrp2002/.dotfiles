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

touch_flag() {
    touch "$FLAG"
}

flag_age() {
    local now mtime
    now=$(date +%s)
    mtime=$(stat -f %m "$FLAG" 2>/dev/null || echo 0)
    echo $((now - mtime))
}

schedule_hide() {
    # Hide 0.6s later unless something touched the flag since (pointer moved
    # into the popup or back onto the item). Terminates: each exit schedules
    # at most one check, and checks never reschedule.
    (
        sleep 0.6
        if [ "$(flag_age)" -ge 1 ]; then
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
