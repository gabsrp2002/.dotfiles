#!/bin/bash

VM_STAT=$(vm_stat)
PAGE_SIZE=$(sysctl -n hw.pagesize)
MEM_TOTAL=$(sysctl -n hw.memsize)

PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active:" | awk '{print $3}' | tr -d '.')
PAGES_WIRED=$(echo "$VM_STAT" | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')

COMPRESSOR_MB=$(top -l 1 -n 0 | grep "PhysMem:" | sed -E 's/.*, ([0-9]+)M compressor.*/\1/')
COMPRESSED_PAGES=$((COMPRESSOR_MB * 1024 * 1024 / PAGE_SIZE))

MEM_USED=$(( (PAGES_ACTIVE + PAGES_WIRED + COMPRESSED_PAGES) * PAGE_SIZE ))
RAM_PERCENT=$(( MEM_USED * 100 / MEM_TOTAL ))

sketchybar --set $NAME label="$RAM_PERCENT%"
