#!/usr/bin/env bash
# Rebuild all Rift workspace items from the live display/workspace set.
# Runs once from sketchybarrc at init and again on every `display_change`
# (dock/undock), so hotplug never leaves stale or missing workspace items.
# Item scheme: space.<arrangement-id>_<workspace-index>, pinned via display=.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

# Memoize icon lookups per run (see plugins/rift.sh): one process spawn
# saved per repeated app. Top-level so the cache survives across displays.
ICON_SEP=$'\x1f'
ICON_CACHE=""
icon_for_app() {
    local app="$1" entry key
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        key="${entry%%"$ICON_SEP"*}"
        if [ "$key" = "$app" ]; then
            printf '%s' "${entry#*"$ICON_SEP"}"
            return 0
        fi
    done <<< "$ICON_CACHE"
    return 1
}
glyph_for_app() {
    # Sets GLYPH. Must be called directly (not via $()) so the cache
    # update survives: command substitution runs in a subshell.
    local app="$1" cached
    if cached=$(icon_for_app "$app"); then
        GLYPH=$cached
    else
        GLYPH=$("$PLUGIN_DIR/icon_map_fn.sh" "$app")
        ICON_CACHE="${ICON_CACHE}${app}${ICON_SEP}${GLYPH}
"
    fi
}

# Serialize rebuilds: a reload fires display_change, which would otherwise run
# a second rebuild concurrently with this one and drop just-added items.
# (mkdir is atomic; no flock on macOS.)
LOCKDIR=/tmp/sketchybar_rebuild.lockdir
mkdir "$LOCKDIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# Snapshot existing workspace items: items that are still desired are kept and
# updated in place instead of removed and re-added. Missing items are added,
# stale ones are removed at the end, and every desired item is fully re-set,
# so rebuilds stay idempotent without flicker.
EXISTING_ITEMS=$(sketchybar --query bar 2>/dev/null | jq -r '.items[]? // empty')
EXISTING_SPACE_ITEMS=$(printf '%s\n' "$EXISTING_ITEMS" | grep '^space\.' | tr '\n' ' ' || true)
EXISTING_PAD=" $EXISTING_SPACE_ITEMS"
DESIRED_ITEMS=""

# Preserve a display's current items when Rift has transiently lost track of
# it (dock turbulence): they are neither refreshed nor swept until Rift
# re-registers the display. Displays truly gone are absent from the
# display loop entirely, so their items still get swept below.
keep_existing_for_display() {
    local arr="$1" name
    for name in $EXISTING_SPACE_ITEMS; do
        case "$name" in
            space."$arr"_*) DESIRED_ITEMS="$DESIRED_ITEMS$name " ;;
        esac
    done
}

SKETCHYBAR_DISPLAYS=$(sketchybar --query displays)
[ -z "$SKETCHYBAR_DISPLAYS" ] && exit 0

build_display() {
    local arr="$1" uuid="$2"
    local WORKSPACES_JSON FOCUSED_INDEX DISPLAY_FRAME
    local window_count icon icons app APPS_JSON WINDOW_FILTER name index
    WORKSPACES_JSON=$(rift-cli query workspaces --display "$uuid")
    # Skip displays Rift has lost track of (e.g. stale entry after dock
    # turbulence: error object instead of a workspace array, or no active
    # workspace at all). They recover on a later rebuild once Rift
    # re-registers the display.
    if [ -z "$WORKSPACES_JSON" ] || echo "$WORKSPACES_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
        keep_existing_for_display "$arr"
        return 0
    fi
    FOCUSED_INDEX=$(echo "$WORKSPACES_JSON" | jq -r '.[] | select(.is_active == true) | .index')
    if [ -z "$FOCUSED_INDEX" ] || [ "$FOCUSED_INDEX" = "null" ]; then
        keep_existing_for_display "$arr"
        return 0
    fi
    # Display frame for the visible-window filter (see plugins/rift.sh).
    DISPLAY_FRAME=$(rift-cli query displays 2>/dev/null | jq -c --arg uuid "$uuid" '.[] | select(.uuid == $uuid) | .frame // empty')
    for index in $(echo "$WORKSPACES_JSON" | jq -r '.[].index'); do
        window_count=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$index" '.[] | select(.index == $idx) | .window_count // 0')
        icon="$index"
        name="space.${arr}_${index}"
        DESIRED_ITEMS="$DESIRED_ITEMS$name "

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
                glyph_for_app "$app"
                icons+=$GLYPH
                icons+="  "
            fi
        done < <(printf '%s\n' "$APPS_JSON")

        # Add only when missing (stale snapshot included: --add is safe to
        # retry, the --subscribe/--set below heals either way). Existing
        # items fall through to the full re-set, which must reset every
        # reused state (colors, drawing, padding, scripts) for idempotency.
        # Everything chains into a single sketchybar invocation per item to
        # avoid one process spawn per operation.
        if [ -n "$icons" ]; then
            label_drawing=on
            padding=4
        else
            label_drawing=off
            padding=6
        fi
        if [ "$index" != "$FOCUSED_INDEX" ] && [ "$window_count" = "0" ]; then
            drawing=off
        else
            drawing=on
        fi
        ADD_ARGS=()
        case "$EXISTING_PAD" in
            *" $name "*) ;;
            *) ADD_ARGS=(--add item "$name" left) ;;
        esac
        sketchybar "${ADD_ARGS[@]}" \
            --subscribe "$name" rift_workspace_changed rift_windows_changed display_change space_windows_change front_app_switched mouse.entered mouse.exited \
            --set "$name" \
            display=$arr \
            drawing=$drawing \
            background.color=$SURFACE_COLOR \
            icon="$icon" \
            label="$icons" \
            icon.color=$SUBTEXT_COLOR \
            label.color=$SUBTEXT_COLOR \
            label.font="sketchybar-app-font:Regular:15.0" \
            label.drawing=$label_drawing \
            icon.padding_right=$padding \
            label.y_offset=-1 \
            click_script="rift-cli execute display focus --uuid $uuid && rift-cli execute workspace switch $index && sketchybar --set \$NAME popup.drawing=off" \
            script="$CONFIG_DIR/plugins/rift_hover.sh $index $uuid" \
            popup.background.border_width=2 \
            popup.background.corner_radius=10 \
            popup.background.border_color=$BORDER_COLOR \
            popup.background.color=$BASE_COLOR \
            popup.blur_radius=20 \
            popup.y_offset=5
    done

    sketchybar --set space.${arr}_${FOCUSED_INDEX} icon.color=$BASE_COLOR label.color=$BASE_COLOR background.color=$LAVENDER
}

for arr in $(echo "$SKETCHYBAR_DISPLAYS" | jq -r '.[]."arrangement-id"'); do
    uuid=$(echo "$SKETCHYBAR_DISPLAYS" | jq -r --argjson a "$arr" '.[] | select(."arrangement-id" == $a) | .UUID')
    [ -n "$uuid" ] && [ "$uuid" != "null" ] && build_display "$arr" "$uuid"
done

# Remove only stale workspace items: anything pre-existing that is not desired
# anymore (undocked display, consolidated workspace set). Items already
# going to be created were kept above, so this never churns them.
DESIRED_PAD=" $DESIRED_ITEMS"
for name in $EXISTING_SPACE_ITEMS; do
    case "$DESIRED_PAD" in
        *" $name "*) ;;
        *) sketchybar --remove "$name" >/dev/null 2>&1 ;;
    esac
done
