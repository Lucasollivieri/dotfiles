#!/bin/bash

killall -9 waybar 
waybar &
killall -9 swaync 
RUNTIME_CONFIG="${XDG_RUNTIME_DIR:-/run/user/$UID}/swaync/config.json"
mkdir -p "$(dirname "$RUNTIME_CONFIG")"
[ -f "$RUNTIME_CONFIG" ] || cp ~/.config/swaync/config.json "$RUNTIME_CONFIG"
swaync -c "$RUNTIME_CONFIG" &
hyprctl reload