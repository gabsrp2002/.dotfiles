#!/bin/bash

# Single-pass CPU usage calculation across all cores (avoids multi-process grep/sed/awk pipeline)
CORE_COUNT=$(sysctl -n machdep.cpu.thread_count 2>/dev/null || echo 8)
CPU_PERCENT=$(ps -A -o %cpu= | awk -v cores="$CORE_COUNT" '{sum += $1} END {printf "%.0f\n", sum / cores}')

sketchybar --set "${NAME:-cpu}" label="${CPU_PERCENT}%"
