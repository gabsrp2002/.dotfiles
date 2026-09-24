#!/usr/bin/env bash
# Rift workspace item plugin. Adapted from
# https://github.com/Kcraft059/sketchybar-config (plugins/spaces/rift)
# to this bar's Catppuccin theme and plugins/icon_map_fn.sh.
#
# Usage: rift.sh <workspace-index> <display-uuid>
# Items are per display (space.<arrangement-id>_<index>) because Rift keeps a
# separate workspace set per macOS Space. Triggered by:
# rift_workspace_changed, rift_windows_changed

source "$CONFIG_DIR/colors.sh"

WORKSPACE_INDEX="$1"
DISPLAY_UUID="$2"

WORKSPACES_JSON=$(rift-cli query workspaces --display "$DISPLAY_UUID" 2>/dev/null)
[ -z "$WORKSPACES_JSON" ] && exit 0

# Remove items for workspaces that no longer exist on this display (e.g. after
# a service restart consolidates the workspace set). Rift has no destroy
# command, so the bar must garbage-collect its own items.
if ! echo "$WORKSPACES_JSON" | jq -e --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx)' >/dev/null; then
    sketchybar --remove "$NAME"
    exit 0
fi

# Highlight this display's focused workspace; hide workspaces on this display
# that are neither focused nor occupied (comm is always visible).
FOCUSED_INDEX=$(echo "$WORKSPACES_JSON" | jq -r '.[] | select(.is_active == true) | .index')
WINDOW_COUNT=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .window_count // 0')
WORKSPACE_NAME=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .name // empty')

if [ "$WORKSPACE_INDEX" = "$FOCUSED_INDEX" ]; then
    sketchybar --set "$NAME" drawing=on background.color=$LAVENDER icon.color=$BASE_COLOR label.color=$BASE_COLOR
elif [ "$WINDOW_COUNT" = "0" ] && [ "$WORKSPACE_NAME" != "comm" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
else
    sketchybar --set "$NAME" drawing=on background.color=$SURFACE_COLOR icon.color=$SUBTEXT_COLOR label.color=$SUBTEXT_COLOR
fi

# Window icons for this workspace (app_name matches Aerospace %{app-name}).
icons=""
while IFS= read -r app; do
    if [ -n "$app" ]; then
        icons+=$("$CONFIG_DIR/plugins/icon_map_fn.sh" "$app")
        icons+="  "
    fi
done < <(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .windows[] | .app_name // .bundle_id // empty')

if [ -n "$icons" ]; then
    sketchybar --set "$NAME" label="$icons" label.drawing=on
else
    sketchybar --set "$NAME" label.drawing=off \
        icon.padding_right=6
fi
