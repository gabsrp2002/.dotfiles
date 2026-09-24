#!/usr/bin/env bash
# Rebuild all Rift workspace items from the live display/workspace set.
# Runs once from sketchybarrc at init and again on every `display_change`
# (dock/undock), so hotplug never leaves stale or missing workspace items.
# Item scheme: space.<arrangement-id>_<workspace-index>, pinned via display=.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

# Serialize rebuilds: a reload fires display_change, which would otherwise run
# a second rebuild concurrently with this one and drop just-added items.
# (mkdir is atomic; no flock on macOS.)
LOCKDIR=/tmp/sketchybar_rebuild.lockdir
mkdir "$LOCKDIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# Drop all workspace items first: removal is idempotent, so rebuilds never
# duplicate (e.g. workspace indexes reused after a service restart).
sketchybar --remove '/space\..*/' >/dev/null 2>&1

SKETCHYBAR_DISPLAYS=$(sketchybar --query displays)
[ -z "$SKETCHYBAR_DISPLAYS" ] && exit 0

build_display() {
    local arr="$1" uuid="$2"
    local WORKSPACES_JSON idx name window_count icon icons app FOCUSED_INDEX
    WORKSPACES_JSON=$(rift-cli query workspaces --display "$uuid")
    # Skip displays Rift has lost track of (e.g. stale entry after dock
    # turbulence: error object instead of a workspace array, or no active
    # workspace at all). They recover on a later rebuild once Rift
    # re-registers the display.
    if [ -z "$WORKSPACES_JSON" ] || echo "$WORKSPACES_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
        return 0
    fi
    FOCUSED_INDEX=$(echo "$WORKSPACES_JSON" | jq -r '.[] | select(.is_active == true) | .index')
    [ -z "$FOCUSED_INDEX" ] || [ "$FOCUSED_INDEX" = "null" ] && return 0
    for index in $(echo "$WORKSPACES_JSON" | jq -r '.[].index'); do
        window_count=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$index" '.[] | select(.index == $idx) | .window_count // 0')
        icon="$index"

        icons=""
        while IFS= read -r app; do
            if [ -n "$app" ]; then
                icons+=$("$PLUGIN_DIR/icon_map_fn.sh" "$app")
                icons+="  "
            fi
        done < <(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$index" '.[] | select(.index == $idx) | .windows[] | .app_name // .bundle_id // empty')

        sketchybar --add item space.${arr}_${index} left \
            --subscribe space.${arr}_${index} rift_workspace_changed rift_windows_changed display_change space_windows_change front_app_switched \
            --set space.${arr}_${index} \
            display=$arr \
            background.color=$SURFACE_COLOR \
            icon="$icon" \
            label="$icons" \
            icon.color=$SUBTEXT_COLOR \
            label.font="sketchybar-app-font:Regular:15.0" \
            label.y_offset=-1 \
            click_script="rift-cli execute display focus --uuid $uuid && rift-cli execute workspace switch $index" \
            script="$CONFIG_DIR/plugins/rift.sh $index $uuid"

        if [ -n "$icons" ]; then
            sketchybar --set space.${arr}_${index} label.drawing=on
        else
            sketchybar --set space.${arr}_${index} label.drawing=off \
                icon.padding_right=6
        fi

        if [ "$index" != "$FOCUSED_INDEX" ] && [ "$window_count" = "0" ]; then
            sketchybar --set space.${arr}_${index} drawing=off
        fi
    done

    sketchybar --set space.${arr}_${FOCUSED_INDEX} icon.color=$BASE_COLOR label.color=$BASE_COLOR background.color=$LAVENDER
}

for arr in $(echo "$SKETCHYBAR_DISPLAYS" | jq -r '.[]."arrangement-id"'); do
    uuid=$(echo "$SKETCHYBAR_DISPLAYS" | jq -r --argjson a "$arr" '.[] | select(."arrangement-id" == $a) | .UUID')
    [ -n "$uuid" ] && [ "$uuid" != "null" ] && build_display "$arr" "$uuid"
done
