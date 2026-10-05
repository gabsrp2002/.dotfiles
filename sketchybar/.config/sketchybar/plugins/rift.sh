#!/usr/bin/env bash
# Rift workspace item plugin. Adapted from
# https://github.com/Kcraft059/sketchybar-config (plugins/spaces/rift)
# to this bar's Catppuccin theme and plugins/icon_map_fn.sh.
#
# Usage: rift.sh <workspace-index> <display-uuid>
# Items are per display (space.<arrangement-id>_<index>) because Rift keeps a
# separate workspace set per macOS Space. Triggered by:
# rift_workspace_changed, rift_windows_changed
#
# The item lists only the windows currently on screen (off-screen scrolling
# columns are excluded); right-click opens a popup with every window
# (see rift_click.sh / rift_popup.sh).

source "$CONFIG_DIR/colors.sh"

WORKSPACE_INDEX="$1"
DISPLAY_UUID="$2"

WORKSPACES_JSON=$(rift-cli query workspaces --display "$DISPLAY_UUID" 2>/dev/null)
# Bail on error shapes (e.g. display lost from Rift's registry after dock
# turbulence): better to keep the last rendered state than to blank items.
if [ -z "$WORKSPACES_JSON" ] || echo "$WORKSPACES_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
    exit 0
fi

# Remove items for workspaces that no longer exist on this display (e.g. after
# a service restart consolidates the workspace set). Rift has no destroy
# command, so the bar must garbage-collect its own items.
if ! echo "$WORKSPACES_JSON" | jq -e --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx)' >/dev/null; then
    sketchybar --remove "$NAME"
    exit 0
fi

# Highlight this display's focused workspace; hide workspaces on this display
# that are neither focused nor occupied.
FOCUSED_INDEX=$(echo "$WORKSPACES_JSON" | jq -r '.[] | select(.is_active == true) | .index')
WINDOW_COUNT=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .window_count // 0')

# Scroll animations report in-flight frames: sampling mid-flight would
# misclassify sliding columns (e.g. a column arriving on screen reads as
# partial and gets filtered out, stuck until the next event). On the focused
# workspace, wait for frames to settle (bounded): compare a compact
# signature across 0.15s polls.
if [ "$WORKSPACE_INDEX" = "$FOCUSED_INDEX" ]; then
    settle_sig() { echo "$1" | jq -c '[.[] | select(.is_active == true) | .windows[] | [.id.idx, .frame]]'; }
    SIG=$(settle_sig "$WORKSPACES_JSON")
    DIRTY=0
    for _ in 1 2 3 4 5; do
        sleep 0.15
        LATEST=$(rift-cli query workspaces --display "$DISPLAY_UUID" 2>/dev/null)
        echo "$LATEST" | jq -e 'type == "array"' >/dev/null 2>&1 || break
        WORKSPACES_JSON="$LATEST"
        NEWSIG=$(settle_sig "$WORKSPACES_JSON")
        if [ "$NEWSIG" = "$SIG" ]; then
            break
        fi
        SIG="$NEWSIG"
        DIRTY=1
    done
    # Frames moved under us: our sample may be mid-flight. Schedule one
    # follow-up refresh past the animation so a transient mis-sample
    # self-heals instead of sticking until the next user event. The follow-up
    # lands settled (no changes -> no further follow-up), so this terminates.
    if [ "$DIRTY" = "1" ]; then
        (sleep 0.8; sketchybar --trigger rift_windows_changed) >/dev/null 2>&1 &
    fi
    FOCUSED_INDEX=$(echo "$WORKSPACES_JSON" | jq -r '.[] | select(.is_active == true) | .index')
    WINDOW_COUNT=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .window_count // 0')
fi

if [ "$WINDOW_COUNT" = "0" ] && [ "$WORKSPACE_INDEX" != "$FOCUSED_INDEX" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

if [ "$WORKSPACE_INDEX" = "$FOCUSED_INDEX" ]; then
    sketchybar --set "$NAME" drawing=on background.color=$LAVENDER icon.color=$BASE_COLOR label.color=$BASE_COLOR icon.padding_right=4
else
    sketchybar --set "$NAME" drawing=on background.color=$SURFACE_COLOR icon.color=$SUBTEXT_COLOR label.color=$SUBTEXT_COLOR icon.padding_right=4
fi

# Visible windows only: the focused column always counts (so the focused
# icon survives mid-animation samples), otherwise ~90% of the frame must be
# inside the display (or cover it, i.e. fullscreen). Inactive workspaces use
# last-known frames. Non-scrolling layouts are unaffected (all tiles pass).
DISPLAY_FRAME=$(rift-cli query displays 2>/dev/null | jq -c --arg uuid "$DISPLAY_UUID" '.[] | select(.uuid == $uuid) | .frame // empty')
# Idx of the truly focused window (tree selection can lag behind real focus;
# join/consume act on selection, but the visibility boost must follow focus).
FOCUSED_IDX=$(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" '.[] | select(.index == $idx) | .windows[] | select(.is_focused == true) | .id.idx // empty')
# One layout query serves both needs: the focused column's idxs (visibility
# boost) and the strip order left-to-right (icon ordering). Inactive
# workspaces resolve via --workspace-id.
if [ "$WORKSPACE_INDEX" = "$FOCUSED_INDEX" ]; then
    LAYOUT_JSON=$(rift-cli query layout --display "$DISPLAY_UUID" 2>/dev/null)
else
    LAYOUT_JSON=$(rift-cli query layout --display "$DISPLAY_UUID" --workspace-id "$WORKSPACE_INDEX" 2>/dev/null)
fi
if [ -n "$FOCUSED_IDX" ] && [ "$FOCUSED_IDX" != "null" ] && [ -n "$LAYOUT_JSON" ]; then
    FOCUSED_COL=$(echo "$LAYOUT_JSON" | jq -c --argjson idx "$FOCUSED_IDX" '[.container_tree.children[] | select(.children[].window_id.idx == $idx) | .children[].window_id.idx] // empty' 2>/dev/null)
else
    FOCUSED_COL=""
fi
[ -z "$FOCUSED_COL" ] || [ "$FOCUSED_COL" = "null" ] && FOCUSED_COL="[]"
LAYOUT_MODE=""
if [ -n "$LAYOUT_JSON" ]; then
    LAYOUT_MODE=$(echo "$LAYOUT_JSON" | jq -r '.mode // empty' 2>/dev/null)
    ORDER=$(echo "$LAYOUT_JSON" | jq -c '.container_tree | [.. | objects | select(.window_id != null) | .window_id.idx]' 2>/dev/null)
else
    ORDER=""
fi
[ -z "$ORDER" ] || [ "$ORDER" = "null" ] && ORDER="[]"
if [ "$LAYOUT_MODE" = "stack" ]; then
    # Stacked windows share one frame, so containment cannot discriminate:
    # only the top (selected) window counts as visible, else the focused
    # one, else fail-open below.
    STACK_TOP=$(echo "$LAYOUT_JSON" | jq -r '(.container_tree | [.. | objects | select(.node_type == "window" and .is_selected == true) | .window_id.idx] | first) // empty' 2>/dev/null)
    if [ -n "$STACK_TOP" ] && [ "$STACK_TOP" != "null" ]; then
        VIS_IDXS="[$STACK_TOP]"
    elif [ -n "$FOCUSED_IDX" ] && [ "$FOCUSED_IDX" != "null" ]; then
        VIS_IDXS="[$FOCUSED_IDX]"
    else
        VIS_IDXS="[]"
    fi
elif [ -n "$DISPLAY_FRAME" ] && [ "$DISPLAY_FRAME" != "null" ]; then
    VIS_FILTER='.[] | select(.index == $idx) | .windows[]
        | select((.id.idx) as $i | ($col | index($i)) or ((.frame // null) as $f | $f != null and (
            ($d.origin.x) as $dx | ($d.origin.y) as $dy |
            ($d.size.width) as $dw | ($d.size.height) as $dh |
            ($f.origin.x) as $fx | ($f.origin.y) as $fy |
            ($f.size.width) as $fw | ($f.size.height) as $fh |
            ([($fx + $fw), ($dx + $dw)] | min) - ([($fx), ($dx)] | max) as $ox |
            ([($fy + $fh), ($dy + $dh)] | min) - ([($fy), ($dy)] | max) as $oy |
            (($ox * $oy) as $ov | ($fw * $fh) as $wa |
              ($ov >= (0.9 * $wa)) or ($ox >= ($dw - 4) and $oy >= ($dh - 4))))))'
    VIS_IDXS=$(echo "$WORKSPACES_JSON" | jq -c --argjson idx "$WORKSPACE_INDEX" --argjson d "$DISPLAY_FRAME" --argjson col "$FOCUSED_COL" "[$VIS_FILTER | .id.idx]")
else
    VIS_IDXS=$(echo "$WORKSPACES_JSON" | jq -c --argjson idx "$WORKSPACE_INDEX" '[.[] | select(.index == $idx) | .windows[].id.idx]')
fi

# Space-padded idx list (plain string match: macOS /bin/bash is 3.2, so no
# associative arrays).
VIS_LIST=" $(echo "$VIS_IDXS" | jq -r '.[]?' | tr '\n' ' ')"

icons=""
have_rows=0
while IFS=$'\x1f' read -r idx app; do
    [ -n "$idx" ] || continue
    have_rows=1
    case "$VIS_LIST" in
        *" $idx "*)
            glyph=$("$CONFIG_DIR/plugins/icon_map_fn.sh" "$app")
            icons+="${glyph}  "
            ;;
    esac
done < <(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" --argjson order "$ORDER" '[.[] | select(.index == $idx) | .windows[] | {i: .id.idx, a: (.app_name // .bundle_id // "?")}] | sort_by((.i) as $i | ($order | index($i)) // 1000000) | .[] | "\(.i)\u001f\(.a)"')

# Fail-open: never render an empty item when windows exist.
if [ -z "$icons" ] && [ "$have_rows" = "1" ]; then
    while IFS=$'\x1f' read -r idx app; do
        [ -n "$idx" ] || continue
        glyph=$("$CONFIG_DIR/plugins/icon_map_fn.sh" "$app")
        icons+="${glyph}  "
    done < <(echo "$WORKSPACES_JSON" | jq -r --argjson idx "$WORKSPACE_INDEX" --argjson order "$ORDER" '[.[] | select(.index == $idx) | .windows[] | {i: .id.idx, a: (.app_name // .bundle_id // "?")}] | sort_by((.i) as $i | ($order | index($i)) // 1000000) | .[] | "\(.i)\u001f\(.a)"')
fi

if [ -n "$icons" ]; then
    sketchybar --set "$NAME" label="$icons" label.drawing=on
else
    sketchybar --set "$NAME" label.drawing=off \
        icon.padding_right=6
fi
