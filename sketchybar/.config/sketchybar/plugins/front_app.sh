#!/bin/bash

MAX_CHARS=20

LABEL="$INFO"

if [[ ${#LABEL} -gt $MAX_CHARS ]]; then
    # Truncate the string and append "..."
    LABEL="${LABEL:0:((MAX_CHARS - 3))}..."
else
    # Keep the original string if it's within the limit
    LABEL="$LABEL"
fi

if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set "$NAME" label="$LABEL"
fi
