#!/usr/bin/env bash
# Interactive Bluetooth popup for SketchyBar.
# - Left-click: show popup immediately, then populate paired devices and
#   auto-scan for nearby unpaired devices in the background while open.
# - Cmd + Click: toggle Bluetooth power on/off.
# - Hover keepalive: generation counter + 0.35s delay across bar item and rows.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

PARENT="bluetooth"
ACTION="${1:-}"
POOL_SIZE=12
ROW_WIDTH=240

FLAG="/tmp/sketchybar_bt_hover"
COUNT_FILE="${FLAG}.count"
OPEN_TRACKER="/tmp/sketchybar_rift_popup_open"
LOOP_PID_FILE="/tmp/sketchybar_bt_loop.pid"
INQUIRY_CACHE="/tmp/sketchybar_bt_inquiry.json"
INQUIRY_PID_FILE="/tmp/sketchybar_bt_inquiry.pid"

touch_flag() {
    touch "$FLAG"
    local count
    count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    echo $((count + 1)) > "$COUNT_FILE"
}

stop_loops() {
    local pid
    for f in "$LOOP_PID_FILE" "$INQUIRY_PID_FILE"; do
        if [ -f "$f" ]; then
            pid=$(cat "$f" 2>/dev/null || true)
            if [ -n "$pid" ]; then
                pkill -P "$pid" 2>/dev/null || true
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$f"
        fi
    done
    pkill -f "blueutil --inquiry" 2>/dev/null || true
}

hide_popup() {
    if [ "$(cat "$OPEN_TRACKER" 2>/dev/null || true)" = "$PARENT" ]; then
        rm -f "$OPEN_TRACKER"
    fi
    sketchybar --set "$PARENT" popup.drawing=off >/dev/null 2>&1
    stop_loops
}

schedule_hide() {
    local seen
    seen=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    (
        sleep 0.35
        if [ "$(cat "$COUNT_FILE" 2>/dev/null || echo 0)" = "$seen" ]; then
            "$0" hide
        fi
    ) >/dev/null 2>&1 &
}

# Handle mouse events from popup children (`hover` arg) or delegated from bluetooth.sh
if [ "$ACTION" = "hover" ]; then
    case "${SENDER:-}" in
        mouse.entered) ACTION="hover_enter" ;;
        mouse.exited)  ACTION="hover_exit" ;;
        *) exit 0 ;;
    esac
fi

case "$ACTION" in
    hover_enter)
        touch_flag
        exit 0
        ;;
    hover_exit)
        schedule_hide
        exit 0
        ;;
    hide)
        hide_popup
        exit 0
        ;;
    toggle_device)
        ADDR="$2"
        IS_PAIRED="${3:-1}"
        ROW_ITEM="${4:-}"
        [ -z "$ADDR" ] && exit 0
        if [ "$(blueutil --is-connected "$ADDR" 2>/dev/null)" = "1" ]; then
            [ -n "$ROW_ITEM" ] && sketchybar --set "$ROW_ITEM" icon.color="$YELLOW"
            blueutil --disconnect "$ADDR" >/dev/null 2>&1
        else
            [ -n "$ROW_ITEM" ] && sketchybar --set "$ROW_ITEM" icon.color="$YELLOW"
            if [ "$IS_PAIRED" = "0" ]; then
                blueutil --pair "$ADDR" >/dev/null 2>&1
            fi
            blueutil --connect "$ADDR" >/dev/null 2>&1
        fi
        "$0" render_once >/dev/null 2>&1
        exit 0
        ;;
esac

# Cmd + Click toggles Bluetooth power
if [ "${MODIFIER:-}" = "cmd" ] || [ "$ACTION" = "toggle_power" ]; then
    hide_popup
    status=$(blueutil --power 2>/dev/null)
    if [ "$status" = "1" ]; then
        blueutil --power 0
        echo "0" > /tmp/sketchybar_bt_state
        sketchybar --set "$PARENT" icon="󰂲"
    else
        blueutil --power 1
        echo "1" > /tmp/sketchybar_bt_state
        sketchybar --set "$PARENT" icon=""
    fi
    exit 0
fi

render_devices() {
    local bt_power
    bt_power=$(blueutil --power 2>/dev/null || echo "0")
    local -a args=()
    local pool_i=0

    if [ "$bt_power" != "1" ]; then
        args+=(--set "${PARENT}.pool.0"
            drawing=on
            width="$ROW_WIDTH"
            icon="󰂲"
            icon.color="$RED"
            label="Bluetooth is Off (click to turn on)"
            label.color="$TEXT_COLOR"
            click_script="$PLUGIN_DIR/click_bluetooth.sh toggle_power")
        pool_i=1
    else
        local paired_json inquiry_json merged_tsv
        paired_json=$(blueutil --paired --format json 2>/dev/null || echo "[]")
        inquiry_json="[]"
        [ -s "$INQUIRY_CACHE" ] && inquiry_json=$(cat "$INQUIRY_CACHE" 2>/dev/null || echo "[]")

        merged_tsv=$(jq -rn \
            --argjson paired "$paired_json" \
            --argjson inq "$inquiry_json" '
            ($paired | map(select(.name != null and .name != "")) | map({
                address: .address,
                name: .name,
                connected: (.connected // false),
                paired: true
            })) as $p
            | ($p | map(.address)) as $p_addrs
            | ($inq | map(select(.name != null and .name != "" and ((.address) as $a | ($p_addrs | index($a)) == null))) | map({
                address: .address,
                name: .name,
                connected: (.connected // false),
                paired: false
            })) as $u
            | ($p + $u)
            | sort_by((if .connected then 0 else 1 end), (if .paired then 0 else 1 end), .name)
            | .[]
            | [.address, .name, (if .connected then "1" else "0" end), (if .paired then "1" else "0" end)]
            | join("\u001f")
        ' 2>/dev/null)

        local addr name conn paired child icon ic lc label
        while IFS=$'\x1f' read -r addr name conn paired; do
            [ -n "$addr" ] || continue
            [ "$pool_i" -lt "$POOL_SIZE" ] || break
            child="${PARENT}.pool.${pool_i}"
            if [ "$conn" = "1" ]; then
                icon="󰂱"
                ic="$GREEN"
                lc="$TEXT_COLOR"
                label="$name"
            elif [ "$paired" = "1" ]; then
                icon=""
                ic="$SUBTEXT_COLOR"
                lc="$SUBTEXT_COLOR"
                label="$name"
            else
                icon="󰂰"
                ic="$PEACH"
                lc="$SUBTEXT_COLOR"
                label="$name (New)"
            fi
            if [ "${#label}" -gt 26 ]; then
                label="${label:0:25}…"
            fi
            args+=(--set "$child"
                drawing=on
                width="$ROW_WIDTH"
                icon="$icon"
                icon.color="$ic"
                label="$label"
                label.color="$lc"
                click_script="$PLUGIN_DIR/click_bluetooth.sh toggle_device '$addr' '$paired' '$child'")
            pool_i=$((pool_i + 1))
        done <<< "$merged_tsv"

        # If inquiry is actively running and we still have room, show a subtle scanning row
        if [ -f "$INQUIRY_PID_FILE" ] && kill -0 "$(cat "$INQUIRY_PID_FILE" 2>/dev/null)" 2>/dev/null && [ "$pool_i" -lt "$POOL_SIZE" ]; then
            child="${PARENT}.pool.${pool_i}"
            args+=(--set "$child"
                drawing=on
                width="$ROW_WIDTH"
                icon="󰑐"
                icon.color="$SAPPHIRE"
                label="Scanning nearby devices…"
                label.color="$SUBTEXT_COLOR"
                click_script="")
            pool_i=$((pool_i + 1))
        fi
    fi

    while [ "$pool_i" -lt "$POOL_SIZE" ]; do
        args+=(--set "${PARENT}.pool.${pool_i}" drawing=off)
        pool_i=$((pool_i + 1))
    done

    [ "${#args[@]}" -gt 0 ] && sketchybar "${args[@]}" >/dev/null 2>&1
}

if [ "$ACTION" = "render_once" ]; then
    render_devices
    exit 0
fi

# Toggle behavior on Left-click (zero-query fast path using OPEN_TRACKER)
touch_flag
PREVIOUS_OPEN=$(cat "$OPEN_TRACKER" 2>/dev/null || true)
if [ "$PREVIOUS_OPEN" = "$PARENT" ] && [ "$ACTION" != "show" ]; then
    hide_popup
    exit 0
fi

# Close any other open popup (wifi or rift workspace popup) and open ours IMMEDIATELY
if [ -n "$PREVIOUS_OPEN" ] && [ "$PREVIOUS_OPEN" != "$PARENT" ] && [ "$PREVIOUS_OPEN" != "wifi" ]; then
    sketchybar --set "$PREVIOUS_OPEN" popup.drawing=off --set wifi popup.drawing=off --set "$PARENT" popup.drawing=on >/dev/null 2>&1
else
    sketchybar --set wifi popup.drawing=off --set "$PARENT" popup.drawing=on >/dev/null 2>&1
fi
printf '%s' "$PARENT" > "$OPEN_TRACKER"

stop_loops
# Also stop any lingering wifi background loops if wifi was open
if [ "$PREVIOUS_OPEN" = "wifi" ]; then
    for wf in /tmp/sketchybar_wifi_loop.pid /tmp/sketchybar_wifi_scan.pid; do
        if [ -f "$wf" ]; then
            wpid=$(cat "$wf" 2>/dev/null || true)
            [ -n "$wpid" ] && { pkill -P "$wpid" 2>/dev/null || true; kill "$wpid" 2>/dev/null || true; }
            rm -f "$wf"
        fi
    done
    pkill -f "scanForNetworks" 2>/dev/null || true
fi

# Populate devices and start background inquiry asynchronously
(
    sh -c 'echo $PPID' > "$INQUIRY_PID_FILE"
    render_devices
    while [ "$(cat "$OPEN_TRACKER" 2>/dev/null || true)" = "$PARENT" ]; do
        out=$(blueutil --inquiry 4 --format json 2>/dev/null)
        [ "$(cat "$OPEN_TRACKER" 2>/dev/null || true)" = "$PARENT" ] || break
        if [ -n "$out" ]; then
            printf '%s' "$out" > "${INQUIRY_CACHE}.tmp" && mv "${INQUIRY_CACHE}.tmp" "$INQUIRY_CACHE"
            "$0" render_once
        fi
        sleep 1
    done
    rm -f "$INQUIRY_PID_FILE"
) >/dev/null 2>&1 &

# Auto-update loop while popup stays open
(
    sh -c 'echo $PPID' > "$LOOP_PID_FILE"
    while [ "$(cat "$OPEN_TRACKER" 2>/dev/null || true)" = "$PARENT" ]; do
        sleep 2
        [ "$(cat "$OPEN_TRACKER" 2>/dev/null || true)" = "$PARENT" ] || break
        "$0" render_once
    done
    rm -f "$LOOP_PID_FILE"
) >/dev/null 2>&1 &
