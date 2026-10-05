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
    # Display frame for the visible-window filter (see plugins/rift.sh).
    DISPLAY_FRAME=$(rift-cli query displays 2>/dev/null | jq -c --arg uuid "$uuid" '.[] | select(.uuid == $uuid) | .frame // empty')
    for index in $(echo "$WORKSPACES_JSON" | jq -r '.[].index'); do
        window_count=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$index" '.[] | select(.index == $idx) | .window_count // 0')
        icon="$index"

        icons=""
        # Initial paint filters every workspace to on-screen frames
        # (rift.sh refreshes apply the stricter rule plus the focused-column
        # boost right after).
        if [ -n "$DISPLAY_FRAME" ] && [ "$DISPLAY_FRAME" != "null" ]; then
            WINDOW_FILTER='.[] | select(.index == $idx) | .windows[]
                | select((.frame // null) as $f | $f == null or (
                    ($d.origin.x) as $dx | ($d.origin.y) as $dy |
                    ($d.size.width) as $dw | ($d.size.height) as $dh |
                    ($f.origin.x) as $fx | ($f.origin.y) as $fy |
                    ($f.size.width) as $fw | ($f.size.height) as $fh |
                    ([($fx + $fw), ($dx + $dw)] | min) - ([($fx), ($dx)] | max) as $ox |
                    ([($fy + $fh), ($dy + $dh)] | min) - ([($fy), ($dy)] | max) as $oy |
                    (($ox * $oy) as $ov | ($fw * $fh) as $wa |
                      ($ov >= (0.9 * $wa)) or ($ox >= ($dw - 4) and $oy >= ($dh - 4)))))
                | .app_name // .bundle_id // empty'
            APPS_JSON=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$index" --argjson d "$DISPLAY_FRAME" "$WINDOW_FILTER")
        else
            APPS_JSON=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$index" '.[] | select(.index == $idx) | .windows[] | .app_name // .bundle_id // empty')
        fi
        while IFS= read -r app; do
            if [ -n "$app" ]; then
                icons+=$("$PLUGIN_DIR/icon_map_fn.sh" "$app")
                icons+="  "
            fi
        done < <(printf '%s\n' "$APPS_JSON")

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
            click_script="$CONFIG_DIR/plugins/rift_click.sh $index $uuid" \
            script="$CONFIG_DIR/plugins/rift.sh $index $uuid" \
            popup.background.border_width=2 \
            popup.background.corner_radius=10 \
            popup.background.border_color=$BORDER_COLOR \
            popup.background.color=$BASE_COLOR \
            popup.blur_radius=20 \
            popup.y_offset=5

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
