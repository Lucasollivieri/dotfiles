#!/bin/bash

killall -9 hyprpaper 2>/dev/null
sleep 0.2
hyprpaper >/dev/null 2>&1 &

killall -9 waybar 2>/dev/null
sleep 0.2
waybar >/dev/null 2>&1 &

killall -9 swaync 2>/dev/null
pkill -9 -f update_clock.sh 2>/dev/null
sleep 0.3

RUNTIME_CONFIG="${XDG_RUNTIME_DIR:-/run/user/$UID}/swaync/config.json"
mkdir -p "$(dirname "$RUNTIME_CONFIG")"
cp ~/.config/swaync/config.json "$RUNTIME_CONFIG"

swaync -c "$RUNTIME_CONFIG" >/dev/null 2>&1 &
~/.config/swaync/update_clock.sh >/dev/null 2>&1 &
