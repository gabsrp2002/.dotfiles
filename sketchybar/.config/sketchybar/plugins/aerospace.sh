#!/usr/bin/env bash

was_removed=true
for sid in $(aerospace list-workspaces --all); do
    if [ "$1" = "$sid" ]; then
        was_removed=false
        break
    fi
done

if $was_removed; then
    echo "workspace $1 was removed"
    sketchybar --remove $NAME
    exit
fi

# If a workspace was not focused, then only update icons and monitor
if [ -z "${FOCUSED_WORKSPACE+x}" ]; then
    icons=""

    IFS=$'\n'
    for sid in $(aerospace list-windows --workspace "$1" --format "%{app-name}"); do
      icons+=$("$CONFIG_DIR/plugins/icon_map_fn.sh" "$sid")
      icons+="  "
    done

    for monitor_id in $(aerospace list-monitors --format %{monitor-id}); do
        for workspace in $(aerospace list-workspaces --monitor $monitor_id); do
            if [ "$workspace" = "$1" ]; then
                monitor=$monitor_id
                break
            fi
        done
    done

    if [ -n "$icons" ]; then
        sketchybar --set $NAME label.drawing=on
    else
        sketchybar --set $NAME label.drawing=off \
            icon.padding_right=6
    fi

    sketchybar --set $NAME display="$monitor" label="$icons"


    for monitor in $(aerospace list-monitors --format %{monitor-id}); do
        reorder_array=()
        for sid in $(aerospace list-workspaces --monitor "$monitor"); do
            reorder_array+=("space.$sid")
        done
        sketchybar --reorder "${reorder_array[@]}"
    done
    exit
fi


# If a workspace was focused, then update space coloring
if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME background.color=0xffB4BEFE icon.color=0xff1E1E2E label.color=0xff1E1E2E
else
    sketchybar --set $NAME background.color=0xff313244 icon.color=0xffA6ADC8 label.color=0xffA6ADC8
fi

