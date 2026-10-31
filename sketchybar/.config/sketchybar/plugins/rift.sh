#!/usr/bin/env bash
# Compatibility shim. Rendering is centralized in rift_refresh.sh; keep this
# name for older callers (e.g. rift_hover.sh's non-mouse fallback).
exec "$CONFIG_DIR/plugins/rift_refresh.sh" "$@"
