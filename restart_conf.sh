#!/bin/bash

pkill hyprpaper
sleep 0.5
hyprpaper &

pkill waybar
sleep 0.5
waybar &

pkill swaync
sleep 0.5
swaync &

