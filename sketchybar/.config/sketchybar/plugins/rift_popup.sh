#!/usr/bin/env bash
# Per-window popup for a Rift workspace item. Lists every window in the
# workspace in strip column order; windows currently on screen get a green
# icon, the rest the default gray.
# Usage: rift_popup.sh <workspace-index> <display-uuid> [show|hide|toggle]
# ($NAME = parent item). Hide closes and drops items; show (re)builds;
# toggle (default) switches.
# Defaults to toggle.

source "$CONFIG_DIR/colors.sh"

WORKSPACE_INDEX="$1"
DISPLAY_UUID="$2"
ACTION="${3:-toggle}"
PARENT="$NAME"

DRAWING=$(sketchybar --query "$PARENT" 2>/dev/null | jq -r '.popup.drawing // "off"')
ESCAPED_PARENT=$(printf '%s' "$PARENT" | sed 's/\./\\./g')
if [ "$ACTION" = "hide" ] || { [ "$ACTION" = "toggle" ] && [ "$DRAWING" = "on" ]; }; then
    sketchybar --set "$PARENT" popup.drawing=off
    for pool_i in 0 1 2 3 4 5 6 7 8 9; do
        sketchybar --set "${PARENT}.winpool.${pool_i}" drawing=off 2>/dev/null
    done
    sketchybar --remove "/${ESCAPED_PARENT}\.win\..*/" >/dev/null 2>&1
    exit 0
fi
# Show path continues below: drop stale children, then rebuild fresh.
sketchybar --remove "/${ESCAPED_PARENT}\.win\..*/" >/dev/null 2>&1

WORKSPACES_JSON=$(rift-cli query workspaces --display "$DISPLAY_UUID" 2>/dev/null)
if [ -z "$WORKSPACES_JSON" ] || echo "$WORKSPACES_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
    exit 0
fi
if ! echo "$WORKSPACES_JSON" | jq -e --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx and (.window_count // 0) > 0)' >/dev/null 2>&1; then
    exit 0
fi

# Visibility rule mirrors plugins/rift.sh: focused column always counts,
# otherwise ~90% of the frame must be inside the display (or cover it).
DISPLAY_FRAME=$(rift-cli query displays 2>/dev/null | jq -c --arg uuid "$DISPLAY_UUID" '.[] | select(.uuid == $uuid) | .frame // empty')
FOCUSED_IDX=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .windows[] | select(.is_focused == true) | .id.idx // empty')
if [ -n "$FOCUSED_IDX" ] && [ "$FOCUSED_IDX" != "null" ]; then
    FOCUSED_COL=$(rift-cli query layout --display "$DISPLAY_UUID" 2>/dev/null | jq -c --argjson idx "$FOCUSED_IDX" '[.container_tree.children[] | select(.children[].window_id.idx == $idx) | .children[].window_id.idx] // empty' 2>/dev/null)
else
    FOCUSED_COL=""
fi
[ -z "$FOCUSED_COL" ] || [ "$FOCUSED_COL" = "null" ] && FOCUSED_COL="[]"
[ -n "$DISPLAY_FRAME" ] && [ "$DISPLAY_FRAME" != "null" ] || DISPLAY_FRAME='{"origin":{"x":0,"y":0},"size":{"width":0,"height":0}}'
IS_ACTIVE=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .is_active // false')
if [ "$IS_ACTIVE" = "true" ]; then
    LAYOUT_JSON=$(rift-cli query layout --display "$DISPLAY_UUID" 2>/dev/null)
else
    LAYOUT_JSON=$(rift-cli query layout --display "$DISPLAY_UUID" --workspace-id "$WORKSPACE_INDEX" 2>/dev/null)
fi
ORDER=$(echo "$LAYOUT_JSON" | jq -c '.container_tree | [.. | objects | select(.window_id != null) | .window_id.idx]' 2>/dev/null)
[ -z "$ORDER" ] || [ "$ORDER" = "null" ] && ORDER="[]"
# Stacked windows share one frame: only the top (selected) window counts as
# visible, else the focused one. Non-stack modes use the frame rule below.
STACK_ONLY=0
STACK_TOP=-1
FOCUSED_NUM=-1
if [ "$(echo "$LAYOUT_JSON" | jq -r '.mode // empty' 2>/dev/null)" = "stack" ]; then
    STACK_ONLY=1
    STACK_TOP=$(echo "$LAYOUT_JSON" | jq -r '(.container_tree | [.. | objects | select(.node_type == "window" and .is_selected == true) | .window_id.idx] | first) // -1' 2>/dev/null)
    [ -z "$STACK_TOP" ] && STACK_TOP=-1
    [ -z "$STACK_TOP" ] || [ "$STACK_TOP" = "null" ] || FOCUSED_NUM="$STACK_TOP"
    if [ -n "$FOCUSED_IDX" ] && [ "$FOCUSED_IDX" != "null" ]; then
        FOCUSED_NUM="$FOCUSED_IDX"
    fi
fi

WINDOWS_TSV=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" --argjson d "$DISPLAY_FRAME" --argjson col "$FOCUSED_COL" --argjson order "$ORDER" --argjson stackonly "$STACK_ONLY" --argjson stacktop "$STACK_TOP" --argjson focused "$FOCUSED_NUM" '
    [.[] | select(.index == $idx) | .windows[]
    | {i: .id.idx, p: .id.pid,
       app: (.app_name // .bundle_id // "?"),
       title: (.title // .app_name // .bundle_id // "?"),
       vis: ((.id.idx) as $i | if $stackonly == 1 then ($i == $stacktop or ($stacktop < 0 and $i == $focused)) else (($col | index($i)) != null or ((.frame // null) as $f | $f != null and (
            ($d.origin.x) as $dx | ($d.origin.y) as $dy |
            ($d.size.width) as $dw | ($d.size.height) as $dh |
            ($f.origin.x) as $fx | ($f.origin.y) as $fy |
            ($f.size.width) as $fw | ($f.size.height) as $fh |
            ([($fx + $fw), ($dx + $dw)] | min) - ([($fx), ($dx)] | max) as $ox |
            ([($fy + $fh), ($dy + $dh)] | min) - ([($fy), ($dy)] | max) as $oy |
            (($ox * $oy) as $ov | ($fw * $fh) as $wa |
              ($ov >= (0.9 * $wa)) or ($ox >= ($dw - 4) and $oy >= ($dh - 4)))))) end)}]
    | sort_by((.i) as $i | ($order | index($i)) // 1000000) | .[] | [.i, .p, .app, .title, .vis] | join("\u001f")')
[ -z "$WINDOWS_TSV" ] && exit 0

# Fixed pool of popup rows, reused across opens: rapid add/remove churn has
# crashed sketchybar before (use-after-free on item teardown), so children
# are updated in place and only hidden, never destroyed, outside rebuilds.
POOL_SIZE=10
pool_i=0
while IFS=$'\x1f' read -r idx pid app title vis; do
    [ -n "$idx" ] || continue
    [ "$pool_i" -lt "$POOL_SIZE" ] || break
    child="${PARENT}.winpool.${pool_i}"
    icon=$("$CONFIG_DIR/plugins/icon_map_fn.sh" "$app")
    [ -z "$icon" ] && icon="•"
    if [ "$vis" = "true" ]; then
        color=$GREEN
    else
        color=$SUBTEXT_COLOR
    fi
    label="${title//$'\n'/ }"
    if [ "${#label}" -gt 45 ]; then
        label="${label:0:45}…"
    fi
    focus_script="rift-cli execute display focus --uuid $DISPLAY_UUID && rift-cli execute workspace switch $WORKSPACE_INDEX && sleep 0.3 && rift-cli execute window focus --window-id '{\"idx\":$idx,\"pid\":$pid}' && sketchybar --set $PARENT popup.drawing=off"
    sketchybar --query "$child" >/dev/null 2>&1 || sketchybar --add item "$child" "popup.${PARENT}" \
        --subscribe "$child" mouse.entered mouse.exited \
        --set "$child" \
        icon.font="sketchybar-app-font:Regular:15.0" \
        background.color="$TRANSPARENT" \
        script="$CONFIG_DIR/plugins/rift_hover.sh $WORKSPACE_INDEX $DISPLAY_UUID"
    sketchybar --set "$child" drawing=on icon="$icon" icon.color="$color" label="$label" label.color="$TEXT_COLOR" click_script="$focus_script"
    pool_i=$((pool_i + 1))
done <<< "$WINDOWS_TSV"
while [ "$pool_i" -lt "$POOL_SIZE" ]; do
    sketchybar --set "${PARENT}.winpool.${pool_i}" drawing=off 2>/dev/null
    pool_i=$((pool_i + 1))
done

sketchybar --set "$PARENT" popup.drawing=on
