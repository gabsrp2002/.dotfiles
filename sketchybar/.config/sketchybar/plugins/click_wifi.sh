#!/usr/bin/env bash
# Interactive Wi-Fi popup for SketchyBar.
# - Hover (mouse.entered on bar item): show popup immediately, then populate
#   current & saved networks and auto-scan for nearby networks in the background.
# - Left-click on bar item: toggle Wi-Fi power on/off.
# - Hover keepalive: generation counter + 0.35s delay across bar item and rows.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"

PARENT="wifi"
ACTION="${1:-}"
POOL_SIZE=15
ROW_WIDTH=240
WIFI_DEV="en0"

FLAG="/tmp/sketchybar_wifi_hover"
COUNT_FILE="${FLAG}.count"
OPEN_TRACKER="/tmp/sketchybar_rift_popup_open"
LOOP_PID_FILE="/tmp/sketchybar_wifi_loop.pid"
SCAN_CACHE="/tmp/sketchybar_wifi_scan.tsv"
SCAN_PID_FILE="/tmp/sketchybar_wifi_scan.pid"
ROWS_CACHE="/tmp/sketchybar_wifi_rows.tsv"
RENDER_SIG="/tmp/sketchybar_wifi_render.sig"
OFFSET_FILE="/tmp/sketchybar_wifi_offset"
RENDER_LOCK="/tmp/sketchybar_wifi_render.lock"

touch_flag() {
    touch "$FLAG"
    local count
    count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    echo $((count + 1)) > "$COUNT_FILE"
}

stop_loops() {
    local pid
    for f in "$LOOP_PID_FILE" "$SCAN_PID_FILE"; do
        if [ -f "$f" ]; then
            pid=$(cat "$f" 2>/dev/null || true)
            if [ -n "$pid" ]; then
                pkill -P "$pid" 2>/dev/null || true
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$f"
        fi
    done
    pkill -f "wifi_scanner.swift" 2>/dev/null || true
    pkill -f "scanForNetworks" 2>/dev/null || true
}

hide_popup() {
    if [ "$(cat "$OPEN_TRACKER" 2>/dev/null || true)" = "$PARENT" ]; then
        rm -f "$OPEN_TRACKER"
    fi
    rm -f "$OFFSET_FILE" "$RENDER_SIG"
    sketchybar --set "$PARENT" popup.drawing=off >/dev/null 2>&1
    stop_loops
}

schedule_hide() {
    local seen
    seen=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    (
        sleep 0.35
        if [ "$(cat "$COUNT_FILE" 2>/dev/null || echo 0)" = "$seen" ]; then
            hide_popup
        fi
    ) >/dev/null 2>&1 &
}

# Handle mouse events from popup children (`hover` arg) or delegated from wifi.sh
if [ "$ACTION" = "hover" ]; then
    case "${SENDER:-}" in
        mouse.entered)  ACTION="hover_enter" ;;
        mouse.exited)   ACTION="hover_exit" ;;
        mouse.scrolled) ACTION="scroll" ;;
        *) exit 0 ;;
    esac
fi

# Fast-path hover keepalive and hide without sourcing colors.sh
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
esac

source "$CONFIG_DIR/colors.sh"

case "$ACTION" in
    connect)
        TARGET_SSID="$2"
        IS_SAVED="${3:-0}"
        IS_OPEN="${4:-0}"
        ROW_ITEM="${5:-}"
        [ -z "$TARGET_SSID" ] && exit 0

        CURRENT_SSID=$(ipconfig getsummary "$WIFI_DEV" 2>/dev/null | awk -F': ' '/  SSID : / {print $2; exit}')
        if [ "$TARGET_SSID" = "$CURRENT_SSID" ]; then
            # Clicking the active network disconnects by cycling airport power
            hide_popup
            networksetup -setairportpower "$WIFI_DEV" off >/dev/null 2>&1
            NAME=wifi "$PLUGIN_DIR/wifi.sh" >/dev/null 2>&1 &
            exit 0
        fi

        [ -n "$ROW_ITEM" ] && sketchybar --set "$ROW_ITEM" icon.color="$YELLOW"

        if [ "$IS_SAVED" = "1" ] || [ "$IS_OPEN" = "1" ]; then
            OUT=$(networksetup -setairportnetwork "$WIFI_DEV" "$TARGET_SSID" 2>&1)
            if ! echo "$OUT" | grep -qiE "Failed to join|Could not find network|Error:"; then
                hide_popup
                NAME=wifi "$PLUGIN_DIR/wifi.sh" >/dev/null 2>&1 &
                exit 0
            fi
            # If the network simply moved out of range, don't ask for a password
            if echo "$OUT" | grep -qi "Could not find network"; then
                hide_popup
                exit 0
            fi
        fi

        # Unknown secured network (or saved network needing a password update): prompt via native dialog
        hide_popup
        ESCAPED_SSID="${TARGET_SSID//\"/\\\"}"
        PASS=$(osascript -e "Tell application \"System Events\" to display dialog \"Enter password for Wi-Fi network \\\"${ESCAPED_SSID}\\\":\" default answer \"\" with title \"Wi-Fi Network\" with hidden answer buttons {\"Cancel\", \"Connect\"} default button \"Connect\"" -e 'text returned of result' 2>/dev/null) || exit 0
        if [ -n "$PASS" ]; then
            networksetup -setairportnetwork "$WIFI_DEV" "$TARGET_SSID" "$PASS" >/dev/null 2>&1
            NAME=wifi "$PLUGIN_DIR/wifi.sh" >/dev/null 2>&1 &
        fi
        exit 0
        ;;
esac

# Left-click on the bar item (no ACTION arg) or explicit toggle_power toggles Wi-Fi power
if [ -z "$ACTION" ] || [ "$ACTION" = "toggle_power" ]; then
    hide_popup
    power_state=$(networksetup -getairportpower "$WIFI_DEV" 2>/dev/null | awk '{print $NF}')
    if [ "$power_state" = "On" ]; then
        sketchybar --set "$PARENT" icon="󰤮" icon.color="$RED" icon.padding_right=3 label.drawing=off >/dev/null 2>&1
        networksetup -setairportpower "$WIFI_DEV" off >/dev/null 2>&1
    else
        sketchybar --set "$PARENT" icon="󰤨" icon.color="$MAUVE" >/dev/null 2>&1
        networksetup -setairportpower "$WIFI_DEV" on >/dev/null 2>&1
    fi
    (sleep 0.5; NAME=wifi "$PLUGIN_DIR/wifi.sh" >/dev/null 2>&1) &
    exit 0
fi

signal_icon() {
    local rssi="${1:--70}"
    if [ "$rssi" -ge -55 ] 2>/dev/null; then
        printf '󰤨'
    elif [ "$rssi" -ge -67 ] 2>/dev/null; then
        printf '󰤥'
    elif [ "$rssi" -ge -77 ] 2>/dev/null; then
        printf '󰤢'
    else
        printf '󰤟'
    fi
}

build_network_rows() {
    local current_ssid power_state preferred_list preferred_nl
    current_ssid=$(ipconfig getsummary "$WIFI_DEV" 2>/dev/null | awk -F': ' '/  SSID : / {print $2; exit}')
    if [ -n "$current_ssid" ]; then
        power_state="On"
    else
        power_state=$(networksetup -getairportpower "$WIFI_DEV" 2>/dev/null | awk '{print $NF}')
    fi

    if [ "$power_state" != "On" ]; then
        printf 'OFF\n' > "${ROWS_CACHE}.tmp" && mv -f "${ROWS_CACHE}.tmp" "$ROWS_CACHE"
        return 0
    fi

    preferred_list=$(networksetup -listpreferredwirelessnetworks "$WIFI_DEV" 2>/dev/null | sed '1d;s/^[[:space:]]*//')
    preferred_nl=$'\n'"$preferred_list"$'\n'

    local sep=$'\x1f'
    local out_active="" out_saved="" out_other=""

    # Row 0: Currently connected network (if any)
    if [ -n "$current_ssid" ]; then
        local safe_ssid="${current_ssid//\'/\'\\\'\'}"
        local disp_ssid="$current_ssid"
        [ "${#disp_ssid}" -gt 26 ] && disp_ssid="${disp_ssid:0:25}…"
        out_active="󰤨${sep}${GREEN}${sep}${disp_ssid}${sep}${TEXT_COLOR}${sep}${PLUGIN_DIR}/click_wifi.sh connect '${safe_ssid}' 1 0"$'\n'
    fi

    # Single pure-bash pass over SCAN_CACHE (no per-line grep process forks)
    if [ -s "$SCAN_CACHE" ]; then
        local ssid rssi is_open icon label safe_ssid
        while IFS=$'\t' read -r ssid rssi is_open; do
            [ -n "$ssid" ] || continue
            [ "$ssid" = "$current_ssid" ] && continue
            icon=$(signal_icon "$rssi")
            safe_ssid="${ssid//\'/\'\\\'\'}"
            case "$preferred_nl" in
                *$'\n'"$ssid"$'\n'*)
                    label="$ssid (Saved)"
                    [ "${#label}" -gt 26 ] && label="${label:0:25}…"
                    out_saved+="${icon}${sep}${SAPPHIRE}${sep}${label}${sep}${TEXT_COLOR}${sep}${PLUGIN_DIR}/click_wifi.sh connect '${safe_ssid}' 1 '${is_open}'"$'\n'
                    ;;
                *)
                    label="$ssid"
                    [ "${#label}" -gt 23 ] && label="${label:0:22}…"
                    if [ "$is_open" != "1" ]; then
                        label="$label  "
                    fi
                    out_other+="${icon}${sep}${SUBTEXT_COLOR}${sep}${label}${sep}${SUBTEXT_COLOR}${sep}${PLUGIN_DIR}/click_wifi.sh connect '${safe_ssid}' 0 '${is_open}'"$'\n'
                    ;;
            esac
        done < "$SCAN_CACHE"
    fi

    printf '%s%s%s' "$out_active" "$out_saved" "$out_other" > "${ROWS_CACHE}.tmp"
    mv -f "${ROWS_CACHE}.tmp" "$ROWS_CACHE"
}

render_viewport() {
    [ -f "$ROWS_CACHE" ] || build_network_rows

    local -a args=()
    local pool_i=0
    local total=0
    local offset=0
    local first_line=""
    IFS= read -r first_line < "$ROWS_CACHE" 2>/dev/null || true

    if [ "$first_line" = "OFF" ]; then
        args+=(--set "${PARENT}.pool.0"
            drawing=on
            width="$ROW_WIDTH"
            icon="󰤮"
            icon.color="$RED"
            label="Wi-Fi is Off (click to turn on)"
            label.color="$TEXT_COLOR"
            click_script="$PLUGIN_DIR/click_wifi.sh toggle_power")
        pool_i=1
    else
        local -a rows_icon=() rows_ic=() rows_label=() rows_lc=() rows_cmd=()
        local icon ic label lc cmd
        while IFS=$'\x1f' read -r icon ic label lc cmd; do
            [ -n "$icon" ] || continue
            rows_icon+=("$icon")
            rows_ic+=("$ic")
            rows_label+=("$label")
            rows_lc+=("$lc")
            rows_cmd+=("$cmd")
        done < "$ROWS_CACHE"

        total="${#rows_label[@]}"
        offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)
        local max_offset=$((total - POOL_SIZE))
        [ "$max_offset" -lt 0 ] && max_offset=0
        [ "$offset" -gt "$max_offset" ] && offset="$max_offset"
        [ "$offset" -lt 0 ] && offset=0
        echo "$offset" > "$OFFSET_FILE"

        local idx="$offset"
        local child
        while [ "$idx" -lt "$total" ] && [ "$pool_i" -lt "$POOL_SIZE" ]; do
            child="${PARENT}.pool.${pool_i}"
            args+=(--set "$child"
                drawing=on
                width="$ROW_WIDTH"
                icon="${rows_icon[$idx]}"
                icon.color="${rows_ic[$idx]}"
                label="${rows_label[$idx]}"
                label.color="${rows_lc[$idx]}"
                click_script="${rows_cmd[$idx]} '$child'")
            pool_i=$((pool_i + 1))
            idx=$((idx + 1))
        done

        # Show scanning indicator at bottom while background scan is active and space remains
        if [ -f "$SCAN_PID_FILE" ] && kill -0 "$(cat "$SCAN_PID_FILE" 2>/dev/null)" 2>/dev/null && [ "$pool_i" -lt "$POOL_SIZE" ]; then
            child="${PARENT}.pool.${pool_i}"
            args+=(--set "$child"
                drawing=on
                width="$ROW_WIDTH"
                icon="󰑐"
                icon.color="$SAPPHIRE"
                label="Scanning networks…"
                label.color="$SUBTEXT_COLOR"
                click_script="")
            pool_i=$((pool_i + 1))
        fi
    fi

    if [ "$total" -gt "$POOL_SIZE" ]; then
        local start_n=$((offset + 1))
        local end_n=$((offset + pool_i))
        [ "$end_n" -gt "$total" ] && end_n="$total"
        args+=(--set "${PARENT}.settings" label="Wi-Fi Settings… (${start_n}–${end_n}/${total} ↕)")
    else
        args+=(--set "${PARENT}.settings" label="Open Wi-Fi Settings…")
    fi

    while [ "$pool_i" -lt "$POOL_SIZE" ]; do
        args+=(--set "${PARENT}.pool.${pool_i}" drawing=off)
        pool_i=$((pool_i + 1))
    done

    if [ "${#args[@]}" -gt 0 ]; then
        local sig="${args[*]}"
        if [ "$(cat "$RENDER_SIG" 2>/dev/null || true)" != "$sig" ]; then
            printf '%s' "$sig" > "$RENDER_SIG"
            sketchybar "${args[@]}" >/dev/null 2>&1
        fi
    fi
}

render_networks() {
    if ! mkdir "$RENDER_LOCK" 2>/dev/null; then
        if [ $(($(date +%s) - $(stat -f %m "$RENDER_LOCK" 2>/dev/null || echo 0))) -gt 5 ]; then
            rm -rf "$RENDER_LOCK"
            mkdir "$RENDER_LOCK" 2>/dev/null || return 0
        else
            return 0
        fi
    fi
    trap 'rmdir "$RENDER_LOCK" 2>/dev/null || true' RETURN
    build_network_rows
    render_viewport
}

if [ "$ACTION" = "scroll" ]; then
    touch_flag
    [ "$(cat "$OPEN_TRACKER" 2>/dev/null || true)" = "$PARENT" ] || exit 0
    delta="${SCROLL_DELTA:-0}"
    [ "$delta" -eq 0 ] 2>/dev/null && exit 0
    offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)
    if [ "$delta" -lt 0 ] 2>/dev/null; then
        step=$(( -delta > 3 ? 3 : (-delta < 1 ? 1 : -delta) ))
        offset=$((offset + step))
    elif [ "$delta" -gt 0 ] 2>/dev/null; then
        step=$(( delta > 3 ? 3 : (delta < 1 ? 1 : delta) ))
        offset=$((offset - step))
        [ "$offset" -lt 0 ] && offset=0
    fi
    echo "$offset" > "$OFFSET_FILE"
    render_viewport
    exit 0
fi

if [ "$ACTION" = "render_once" ]; then
    render_networks
    exit 0
fi

# Hover on bar item (`show`): keep alive if already open, otherwise open popup
touch_flag
PREVIOUS_OPEN=$(cat "$OPEN_TRACKER" 2>/dev/null || true)
if [ "$PREVIOUS_OPEN" = "$PARENT" ]; then
    exit 0
fi

echo 0 > "$OFFSET_FILE"
rm -f "$RENDER_SIG" "$RENDER_LOCK"

# Close any other open popup (bluetooth or rift workspace popup) and open ours IMMEDIATELY
if [ -n "$PREVIOUS_OPEN" ] && [ "$PREVIOUS_OPEN" != "$PARENT" ] && [ "$PREVIOUS_OPEN" != "bluetooth" ]; then
    sketchybar --set "$PREVIOUS_OPEN" popup.drawing=off --set bluetooth popup.drawing=off --set "$PARENT" popup.drawing=on >/dev/null 2>&1
else
    sketchybar --set bluetooth popup.drawing=off --set "$PARENT" popup.drawing=on >/dev/null 2>&1
fi
printf '%s' "$PARENT" > "$OPEN_TRACKER"

stop_loops
# Also stop any lingering bluetooth background loops if bluetooth was open
if [ "$PREVIOUS_OPEN" = "bluetooth" ]; then
    "$PLUGIN_DIR/click_bluetooth.sh" hide >/dev/null 2>&1 &
fi

# Populate networks and start background CoreWLAN scan loop asynchronously.
(
    sh -c 'echo $PPID' > "$SCAN_PID_FILE"
    render_networks
    SCRIPT_PATH="$0" swift "$PLUGIN_DIR/wifi_scanner.swift" 2>/dev/null
    rm -f "$SCAN_PID_FILE"
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
