#!/bin/bash

MAX_CHARS=20

if [ -z "$INFO" ]; then
  # No event payload (e.g. first run at reload): query the front app directly.
  INFO=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
fi
LABEL="$INFO"

if [[ ${#LABEL} -gt $MAX_CHARS ]]; then
    # Truncate the string and append "..."
    LABEL="${LABEL:0:((MAX_CHARS - 3))}..."
else
    # Keep the original string if it's within the limit
    LABEL="$LABEL"
fi

if [ -n "$LABEL" ]; then
  sketchybar --set "$NAME" label="$LABEL"
fi
