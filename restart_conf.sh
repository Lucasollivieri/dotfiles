#!/bin/bash

pkill hyprpaper
sleep 0.5
hyprpaper &
disown

pkill waybar
sleep 0.5
waybar &
disown

pkill swaync
pkill -f update_clock.sh
sleep 0.5
swaync &
disown
~/.config/swaync/update_clock.sh &
disown
