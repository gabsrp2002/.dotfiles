#!/usr/bin/env bash
# Single dispatcher + renderer for the per-display Rift workspace items.
#
# One hidden sketchybar item (rift_watcher) subscribes to the Rift events and
# runs this script; the visible item scripts only handle mouse enter/exit (hover
# popups). This replaces the old fan-out where every workspace item ran its own
# copy of rift.sh for every event (24 script runs per workspace switch), plus
# the separate rebuild_spaces.sh pass for item creation.
#
# Item scheme: space.<arrangement-id>_<workspace-index>, pinned via display=.
#
# Runs are coalesced: while one refresh is in flight, further events only set a
# pending marker, and the in-flight run does a single trailing re-run. That
# keeps a burst (workspace_changed + 3x windows_changed + display changes) from
# spawning a renderer per event while still converging on the final state.
#
# Layout of a run:
#   1. create/refresh the item set (add new, remember stale for removal),
#   2. apply highlight/visibility for every workspace from is_active and
#      window_count (no frame sampling, no settle sleep),
#   3. only then compute window icons (layout/frame queries, glyph mapping),
#   4. one batched sketchybar invocation per phase, skipping unchanged state.
#
# Usage: rift_refresh.sh [--init]
#   --init  startup: discard the rendered-state cache and rebuild statics.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

GLYPH_CACHE=/tmp/sketchybar_rift_glyphs
DISPLAY_CACHE=/tmp/sketchybar_rift_displays
SK_DISPLAY_CACHE=/tmp/sketchybar_rift_sk_displays
ITEMS_CACHE=/tmp/sketchybar_rift_items
ICON_MAP="$PLUGIN_DIR/icon_map_fn.sh"
STATE_DIR=/tmp/sketchybar_rift_state
LOCKDIR=/tmp/sketchybar_rift_refresh.lockdir
PENDING=/tmp/sketchybar_rift_refresh.pending
PENDING_REBUILD=/tmp/sketchybar_rift_refresh.pending_rebuild
TRAILING_GEN=/tmp/sketchybar_rift_trailing_gen
# One shot after Rift's animation (animation_duration = 0.3s) to correct icon
# samples taken mid-flight. Every user-event run bumps a generation; only the
# latest scheduled check fires, so the refresh lands 0.45s after the last run.
TRAILING_DELAY=0.45

# ---------------------------------------------------------------------------
# App -> glyph map, persisted across runs. Invalidated when icon_map_fn.sh is
# newer than the cache (edit the mapping -> next run repopulates).
# ---------------------------------------------------------------------------
ICON_SEP=$'\x1f'
ICON_CACHE=""

load_icons() {
    ICON_CACHE=""
    if [ -f "$GLYPH_CACHE" ] && [ ! "$ICON_MAP" -nt "$GLYPH_CACHE" ]; then
        ICON_CACHE=$(cat "$GLYPH_CACHE")
    else
        : > "$GLYPH_CACHE"
    fi
}

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
    # Sets GLYPH. Must be called directly (not via $()) so the in-memory cache
    # update survives: command substitution runs in a subshell.
    local app="$1" cached
    if cached=$(icon_for_app "$app"); then
        GLYPH=$cached
    else
        GLYPH=$("$ICON_MAP" "$app")
        printf '%s%s%s\n' "$app" "$ICON_SEP" "$GLYPH" >> "$GLYPH_CACHE"
        ICON_CACHE="${ICON_CACHE}${app}${ICON_SEP}${GLYPH}
"
    fi
}

# ---------------------------------------------------------------------------
# Coalescing lock. mkdir is atomic; the PID file lets a later run reclaim a
# lock whose owner died (e.g. sketchybar killed mid-run).
# ---------------------------------------------------------------------------
acquire_lock() {
    local pid age now
    while ! mkdir "$LOCKDIR" 2>/dev/null; do
        touch "$PENDING" 2>/dev/null || true
        [ "${SENDER:-}" = "display_change" ] && touch "$PENDING_REBUILD" 2>/dev/null || true
        pid=$(cat "$LOCKDIR/pid" 2>/dev/null || true)
        now=$(date +%s)
        age=$(( now - $(cat "$LOCKDIR/ts" 2>/dev/null || echo "$now") ))
        # A healthy run finishes in well under a second; anything this old is
        # an orphan (or PID reuse), so reclaim it.
        if [ "$age" -ge 30 ]; then
            rm -rf "$LOCKDIR"
            continue
        fi
        if [ -n "$pid" ]; then
            if ! kill -0 "$pid" 2>/dev/null; then
                rm -rf "$LOCKDIR"
                continue
            fi
        else
            # Lock exists but the owner has not written its PID yet. Give it a
            # few seconds, then treat it as stale.
            if [ "$age" -ge 5 ]; then
                rm -rf "$LOCKDIR"
                continue
            fi
        fi
        return 1
    done
    echo $$ > "$LOCKDIR/pid"
    date +%s > "$LOCKDIR/ts"
    return 0
}

# ---------------------------------------------------------------------------
# Static item properties. Only applied when an item is created (or on a
# display_change rebuild), never on the hot render path.
# ---------------------------------------------------------------------------
append_static_args() {
    local name="$1" arr="$2" index="$3" uuid="$4" add="$5"
    [ "$add" = "1" ] && STATIC_ARGS+=(--add item "$name" left)
    STATIC_ARGS+=(
        --subscribe "$name" mouse.entered mouse.exited
        --set "$name" \
            display="$arr" \
            icon="$index" \
            label.font="sketchybar-app-font:Regular:15.0" \
            label.y_offset=-1 \
            click_script="rift-cli execute display focus --uuid $uuid && rift-cli execute workspace switch $index && sketchybar --set \$NAME popup.drawing=off" \
            script="$PLUGIN_DIR/rift_hover.sh $index $uuid" \
            popup.background.border_width=2 \
            popup.background.corner_radius=10 \
            popup.background.border_color="$BORDER_COLOR" \
            popup.background.color="$BASE_COLOR" \
            popup.blur_radius=20 \
            popup.y_offset=5
    )
}

keep_existing_for_display() {
    local arr="$1" name
    for name in $EXISTING_SPACE_ITEMS; do
        case "$name" in
            space."$arr"_*) DESIRED="$DESIRED$name " ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Icon label for one workspace. Returns LABEL, LABEL_DRAWING, LABEL_PADDING.
# Shell-variable output avoids spawning a sketchybar process per item.
# ---------------------------------------------------------------------------
render_label() {
    local uuid="$1" index="$2" focused="$3" frame="$4" focused_idx="$5"
    local layout_json mode order col stack_top stack_only rows
    local widx app vis icons have_rows

    LABEL=""
    LABEL_DRAWING=off
    LABEL_PADDING=6

    if [ "$index" = "$focused" ]; then
        layout_json=$(rift-cli query layout --display "$uuid" 2>/dev/null)
    else
        layout_json=$(rift-cli query layout --display "$uuid" --workspace-id "$index" 2>/dev/null)
    fi
    [ -z "$layout_json" ] && layout_json='{}'

    # One jq pass yields: mode, strip order, focused column, stack top.
    local meta
    meta=$(echo "$layout_json" | jq -r --argjson fidx "${focused_idx:-null}" '
        [ (.mode // ""),
          ((.container_tree | [.. | objects | select(.window_id != null) | .window_id.idx]) | tojson),
          (if $fidx != null then
             ([.container_tree.children[]? | select(any(.children[]?; .window_id.idx == $fidx)) | .children[]?.window_id.idx] | tojson)
           else "[]" end),
          (((.container_tree | [.. | objects | select(.node_type == "window" and .is_selected == true) | .window_id.idx])[0]) // null | tojson)
        ] | join("\u001f")' 2>/dev/null)
    IFS=$'\x1f' read -r mode order col stack_top <<< "$meta"
    [ -n "$mode" ] || mode=""
    [ -n "$order" ] || order="[]"
    [ -n "$col" ] || col="[]"
    [ -n "$stack_top" ] || stack_top="null"

    stack_only=0
    if [ "$mode" = "stack" ]; then
        stack_only=1
        if [ "$stack_top" = "null" ]; then
            stack_top=-1
            [ -n "$focused_idx" ] && stack_top="$focused_idx"
        fi
    else
        stack_top=-1
    fi
    [ -n "$focused_idx" ] || focused_idx=-1

    rows=$(echo "$WORKSPACES_JSON" | jq -r \
        --argjson idx "$index" \
        --argjson d "$frame" \
        --argjson col "$col" \
        --argjson order "$order" \
        --argjson stackonly "$stack_only" \
        --argjson stacktop "$stack_top" \
        --argjson focused "$focused_idx" '
        [.[] | select(.index == $idx) | .windows[]
         | {i: .id.idx, a: (.app_name // .bundle_id // "?"),
            vis: (if $stackonly == 1 then
                    ((.id.idx) == $stacktop or ($stacktop < 0 and (.id.idx) == $focused))
                  elif $d != null then
                    ((.id.idx) as $i | (($col | index($i)) != null) or ((.frame // null) as $f | $f != null and (
                      ($d.origin.x) as $dx | ($d.origin.y) as $dy |
                      ($d.size.width) as $dw | ($d.size.height) as $dh |
                      ($f.origin.x) as $fx | ($f.origin.y) as $fy |
                      ($f.size.width) as $fw | ($f.size.height) as $fh |
                      ([($fx + $fw), ($dx + $dw)] | min) - ([($fx), ($dx)] | max) as $ox |
                      ([($fy + $fh), ($dy + $dh)] | min) - ([($fy), ($dy)] | max) as $oy |
                      (($ox * $oy) as $ov | ($fw * $fh) as $wa |
                        ($ov >= (0.9 * $wa)) or ($ox >= ($dw - 4) and $oy >= ($dh - 4))))))
                  else true end)}]
        | sort_by((.i) as $i | ($order | index($i)) // 1000000)
        | .[] | [((.i) | tostring), .a, (if .vis then "1" else "0" end)] | join("\u001f")' 2>/dev/null)

    icons=""
    have_rows=0
    while IFS=$'\x1f' read -r widx app vis; do
        [ -n "$widx" ] || continue
        have_rows=1
        if [ "$vis" = "1" ]; then
            glyph_for_app "$app"
            icons+="${GLYPH}  "
        fi
    done <<< "$rows"

    # Fail-open: never render an empty label when windows exist.
    if [ -z "$icons" ] && [ "$have_rows" = "1" ]; then
        while IFS=$'\x1f' read -r widx app vis; do
            [ -n "$widx" ] || continue
            glyph_for_app "$app"
            icons+="${GLYPH}  "
        done <<< "$rows"
    fi

    if [ -n "$icons" ]; then
        LABEL="$icons"
        LABEL_DRAWING=on
        LABEL_PADDING=4
    fi
}

# ---------------------------------------------------------------------------
# One display: sync its items, highlight immediately, then fill icons.
# ---------------------------------------------------------------------------
render_display() {
    local arr="$1" uuid="$2" rebuild="$3"
    local WORKSPACES_JSON focused focus_mode meta tag index active wc mode fidx name
    local drawing bg ic lc hi meta_read=0
    local HI_ARGS=() LBL_ARGS=()
    local -a drawn_idx=() drawn_fidx=()

    WORKSPACES_JSON=$(rift-cli query workspaces --display "$uuid" 2>/dev/null)
    if [ -z "$WORKSPACES_JSON" ]; then
        keep_existing_for_display "$arr"
        return 0
    fi

    # One jq pass validates the shape and yields the display's metadata:
    #   F <focused index> <focused layout mode>
    #   W <index> <active> <window count> <layout mode> <focused window idx>
    #   E (Rift has no usable workspace set for this display)
    meta=$(echo "$WORKSPACES_JSON" | jq -r '
        if type != "array" then "E"
        elif ([.[] | select(.is_active == true)][0].index) == null then "E"
        else
          ([.[] | select(.is_active == true)][0].index) as $f |
          ("F\u001f\($f)\u001f\([.[] | select(.index == $f)][0].layout_mode // "")"),
          (.[] | "W\u001f\(.index)\u001f\(.is_active)\u001f\(.window_count // 0)\u001f\(.layout_mode // "")\u001f\((([.windows[] | select(.is_focused == true) | .id.idx] | .[0]) // ""))")
        end' 2>/dev/null)

    focused=""
    # Pass 1: item set + highlight/visibility (no frame or layout sampling).
    while IFS=$'\x1f' read -r tag index active wc mode fidx; do
        case "$tag" in
            E)
                keep_existing_for_display "$arr"
                return 0
                ;;
            F)
                focused="$index"
                focus_mode="$active"
                meta_read=1
                continue
                ;;
            W) ;;
            *) continue ;;
        esac
        [ -n "$index" ] || continue
        name="space.${arr}_${index}"
        DESIRED="$DESIRED$name "

        if [ "$index" = "$focused" ]; then
            bg="$LAVENDER"; ic="$BASE_COLOR"; lc="$BASE_COLOR"
        else
            bg="$SURFACE_COLOR"; ic="$SUBTEXT_COLOR"; lc="$SUBTEXT_COLOR"
        fi
        if [ "$wc" = "0" ] && [ "$index" != "$focused" ]; then
            drawing="off"
        else
            drawing="on"
            drawn_idx+=("$index")
            drawn_fidx+=("$fidx")
        fi

        case "$EXISTING_PAD" in
            *" $name "*) 
                if [ "$rebuild" = "1" ]; then
                    append_static_args "$name" "$arr" "$index" "$uuid" 0
                fi
                ;;
            *)
                append_static_args "$name" "$arr" "$index" "$uuid" 1
                EXISTING_PAD="$EXISTING_PAD$name "
                ;;
        esac

        hi="${drawing}${ICON_SEP}${bg}${ICON_SEP}${ic}${ICON_SEP}${lc}"
        if [ "$(cat "$STATE_DIR/$name.hi" 2>/dev/null || true)" != "$hi" ]; then
            HI_ARGS+=(--set "$name" drawing="$drawing" background.color="$bg" icon.color="$ic" label.color="$lc")
            printf '%s' "$hi" > "$STATE_DIR/$name.hi"
        fi
    done <<< "$meta"

    [ "$meta_read" = "1" ] || { keep_existing_for_display "$arr"; return 0; }
    [ "$focus_mode" = "scrolling" ] && TRAILING_WANTED=1

    local frame
    frame=$(echo "$RIFT_DISPLAYS" | jq -c --arg uuid "$uuid" '.[] | select(.uuid == $uuid) | .frame' 2>/dev/null)
    [ -n "$frame" ] || frame=null

    # Create missing items first, then paint highlight. Both are single calls.
    if [ "${#STATIC_ARGS[@]}" -gt 0 ]; then
        sketchybar "${STATIC_ARGS[@]}" >/dev/null 2>&1
        STATIC_ARGS=()
    fi
    if [ "${#HI_ARGS[@]}" -gt 0 ]; then
        sketchybar "${HI_ARGS[@]}" >/dev/null 2>&1
    fi

    # Pass 2: icons. Only for items that are actually drawn.
    local i idx
    for i in "${!drawn_idx[@]}"; do
        idx="${drawn_idx[$i]}"
        name="space.${arr}_${idx}"
        render_label "$uuid" "$idx" "$focused" "$frame" "${drawn_fidx[$i]}"
        local lbl_state
        lbl_state="${LABEL}${ICON_SEP}${LABEL_DRAWING}${ICON_SEP}${LABEL_PADDING}"
        if [ "$(cat "$STATE_DIR/$name.lbl" 2>/dev/null || true)" != "$lbl_state" ]; then
            if [ "$LABEL_DRAWING" = "on" ]; then
                LBL_ARGS+=(--set "$name" label="$LABEL" label.drawing=on icon.padding_right="$LABEL_PADDING")
            else
                LBL_ARGS+=(--set "$name" label.drawing=off icon.padding_right="$LABEL_PADDING")
            fi
            printf '%s' "$lbl_state" > "$STATE_DIR/$name.lbl"
        fi
    done

    if [ "${#LBL_ARGS[@]}" -gt 0 ]; then
        sketchybar "${LBL_ARGS[@]}" >/dev/null 2>&1
    fi
}

# ---------------------------------------------------------------------------
# Full refresh over all displays, plus stale item sweep.
# ---------------------------------------------------------------------------
refresh() {
    local rebuild="$1"
    local SK_DISPLAYS EXISTING_ITEMS arr uuid name
    local -a STATIC_ARGS=()
    DESIRED=""
    TRAILING_WANTED=0

    [ "$rebuild" = "1" ] && rm -rf "$STATE_DIR"
    mkdir -p "$STATE_DIR"

    # The display set (and frames) only changes on hotplug/arrangement change,
    # which arrives as display_change (rebuild). Cache both queries otherwise.
    if [ "$rebuild" = "1" ] || [ ! -s "$SK_DISPLAY_CACHE" ]; then
        SK_DISPLAYS=$(sketchybar --query displays 2>/dev/null)
        [ -n "$SK_DISPLAYS" ] && printf '%s' "$SK_DISPLAYS" > "$SK_DISPLAY_CACHE"
    else
        SK_DISPLAYS=$(cat "$SK_DISPLAY_CACHE" 2>/dev/null)
    fi
    [ -z "$SK_DISPLAYS" ] && return 0
    if [ "$rebuild" = "1" ] || [ ! -s "$DISPLAY_CACHE" ]; then
        RIFT_DISPLAYS=$(rift-cli query displays 2>/dev/null)
        [ -n "$RIFT_DISPLAYS" ] && printf '%s' "$RIFT_DISPLAYS" > "$DISPLAY_CACHE"
    else
        RIFT_DISPLAYS=$(cat "$DISPLAY_CACHE" 2>/dev/null)
    fi

    # Item set: the cache is written at the end of every run and only the
    # rebuild path (init/display_change) pays for a sketchybar query.
    if [ "$rebuild" = "1" ] || [ ! -s "$ITEMS_CACHE" ]; then
        EXISTING_ITEMS=$(sketchybar --query bar 2>/dev/null | jq -r '.items[]? // empty' 2>/dev/null)
        EXISTING_SPACE_ITEMS=$(printf '%s\n' "$EXISTING_ITEMS" | grep '^space\.' | tr '\n' ' ' || true)
    else
        EXISTING_SPACE_ITEMS=$(cat "$ITEMS_CACHE" 2>/dev/null)
    fi
    EXISTING_PAD=" $EXISTING_SPACE_ITEMS"

    for arr in $(echo "$SK_DISPLAYS" | jq -r '.[]."arrangement-id"' 2>/dev/null); do
        uuid=$(echo "$SK_DISPLAYS" | jq -r --argjson a "$arr" \
            '.[] | select(."arrangement-id" == $a) | .UUID' 2>/dev/null)
        [ -n "$uuid" ] && [ "$uuid" != "null" ] || continue
        render_display "$arr" "$uuid" "$rebuild"
    done

    # Sweep only what is no longer desired; displays Rift transiently lost are
    # kept via keep_existing_for_display(), so their items are in DESIRED.
    local desired_pad=" $DESIRED"
    for name in $EXISTING_SPACE_ITEMS; do
        case "$desired_pad" in
            *" $name "*) ;;
            *)
                sketchybar --remove "$name" >/dev/null 2>&1
                rm -f "$STATE_DIR/$name.hi" "$STATE_DIR/$name.lbl"
                ;;
        esac
    done

    printf '%s' "$DESIRED" > "$ITEMS_CACHE"
    maybe_schedule_trailing
}

maybe_schedule_trailing() {
    local gen
    [ "$TRAILING_WANTED" = "1" ] || return 0
    case "${SENDER:-}" in
        rift_trailing_refresh) return 0 ;;
        rift_workspace_changed|rift_windows_changed) ;;
        *) return 0 ;;
    esac
    # Debounce: only the most recently scheduled check survives; earlier
    # sleepers see a newer generation and exit without triggering.
    gen=$(cat "$TRAILING_GEN" 2>/dev/null || echo 0)
    gen=$(( gen + 1 ))
    printf '%s' "$gen" > "$TRAILING_GEN"
    (
        sleep "$TRAILING_DELAY"
        [ "$(cat "$TRAILING_GEN" 2>/dev/null || echo 0)" = "$gen" ] || exit 0
        sketchybar --trigger rift_trailing_refresh
    ) >/dev/null 2>&1 &
}

# ---------------------------------------------------------------------------
# Main: coalesced run loop.
# ---------------------------------------------------------------------------
REBUILD=0
if [ "${1:-}" = "--init" ]; then
    REBUILD=1
    # Fresh sketchybar instance: old rendered-state files are meaningless.
    rm -rf "$STATE_DIR" "$LOCKDIR" "$PENDING" "$PENDING_REBUILD"
    rm -f "$TRAILING_GEN"
fi

if ! acquire_lock; then
    exit 0
fi
trap 'rm -rf "$LOCKDIR"' EXIT

load_icons

while :; do
    rm -f "$PENDING"
    [ "$REBUILD" = "1" ] && rm -rf "$STATE_DIR"
    refresh "$REBUILD"

    if [ -e "$PENDING" ]; then
        [ -e "$PENDING_REBUILD" ] && REBUILD=1
        rm -f "$PENDING" "$PENDING_REBUILD"
        continue
    fi
    break
done

rm -rf "$LOCKDIR"
trap - EXIT

# A trigger can land between the pending check and the lock release. Re-enter
# once so that event is not silently dropped; the next real event would heal it
# anyway, so this is a best-effort close of a tiny window.
if [ -e "$PENDING" ]; then
    rm -f "$PENDING"
    exec "$0" "$@"
fi
