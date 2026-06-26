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
sleep 0.5
swaync &
disown

