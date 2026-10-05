#!/usr/bin/env bash
# Dispatch clicks on a Rift workspace item: right-click toggles the
# per-window popup, anything else switches to the workspace.
# Usage: rift_click.sh <workspace-index> <display-uuid>  ($NAME = clicked
# item; $BUTTON = left|right|other from sketchybar)

if [ "${BUTTON:-left}" = "right" ]; then
    exec "$CONFIG_DIR/plugins/rift_popup.sh" "$1" "$2"
fi

rift-cli execute display focus --uuid "$2" && rift-cli execute workspace switch "$1"
