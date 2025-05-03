#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Check if modifier is "cmd"
if [[ "$MODIFIER" = "cmd" ]]; then
    # Check current VPN status
    sketchybar --set $NAME updates=off icon=󰓦 icon.color=$SAPPHIRE
    VPN_STATUS=$(scutil --nc list | grep Connected)
    if [[ "$VPN_STATUS" == *Connected* ]]; then
        sketchybar --set $NAME label="Turning off Tailscale..." updates=off
        /usr/local/bin/tailscale down
        scutil --nc stop "Tailscale"

        sketchybar --set $NAME label="Tailscale disconnected"
    else
        sketchybar --set $NAME label="Starting Tailscale..." updates=off
        /usr/local/bin/tailscale up

        for i in {1..10}; do
            if [[ "$(/usr/local/bin/tailscale status)" = *"-"* ]]; then
                sketchybar --set $NAME label="Tailscale connected" updates=on
                exit
            fi
            sleep 1
        done

        scutil --nc stop "Tailscale"
        sketchybar --set $NAME label="Failed to start Tailscale"
    fi
    sketchybar --set $NAME updates=on
    exit
fi

# Open Network preferences if modifier is not "cmd"
open /System/Library/PreferencePanes/Network.prefPane
