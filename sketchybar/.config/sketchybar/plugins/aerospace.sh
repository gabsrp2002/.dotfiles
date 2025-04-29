#!/usr/bin/env bash

# Check if it's the initialization
if [ -z "${FOCUSED_WORKSPACE+x}" ]; then
    exit
fi

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

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME background.color=0xffB4BEFE icon.color=0xff1E1E2E label.color=0xff1E1E2E display="$monitor" label="$icons"
else
    sketchybar --set $NAME background.color=0xff313244 icon.color=0xffA6ADC8 label.color=0xffA6ADC8 display="$monitor" label="$icons"
fi

