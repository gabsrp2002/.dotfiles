#!/usr/bin/env bash
# Rift workspace item plugin. Adapted from
# https://github.com/Kcraft059/sketchybar-config (plugins/spaces/rift)
# to this bar's Catppuccin theme and plugins/icon_map_fn.sh.
#
# Usage: rift.sh <workspace-index>
# Triggered by: rift_workspace_changed, rift_windows_changed

WORKSPACE_INDEX="$1"

WORKSPACES_JSON=$(rift-cli query workspaces 2>/dev/null)
[ -z "$WORKSPACES_JSON" ] && exit 0

# Highlight the focused workspace.
FOCUSED_INDEX=$(echo "$WORKSPACES_JSON" | jq -r '.[] | select(.is_active == true) | .index')
if [ "$WORKSPACE_INDEX" = "$FOCUSED_INDEX" ]; then
    sketchybar --set "$NAME" background.color=0xffB4BEFE icon.color=0xff1E1E2E label.color=0xff1E1E2E
else
    sketchybar --set "$NAME" background.color=0xff313244 icon.color=0xffA6ADC8 label.color=0xffA6ADC8
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
