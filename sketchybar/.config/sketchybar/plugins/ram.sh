#!/bin/bash

# Parse memory usage directly from vm_stat and sysctl (avoids the heavy ~150ms `top` run)
RAM_PERCENT=$(vm_stat | awk -v total="$(sysctl -n hw.memsize)" -v page="$(sysctl -n hw.pagesize)" '
/Pages active:/ { gsub(/\./, "", $3); active = $3 }
/Pages wired down:/ { gsub(/\./, "", $4); wired = $4 }
/Pages occupied by compressor:/ { gsub(/\./, "", $5); comp = $5 }
END {
  used = (active + wired + comp) * page
  printf "%.0f\n", (used * 100 / total)
}')

sketchybar --set "${NAME:-ram}" label="${RAM_PERCENT}%"
