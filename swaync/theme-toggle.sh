#!/usr/bin/env bash
set -euo pipefail

schema="org.gnome.desktop.interface"
if ! command -v gsettings >/dev/null 2>&1; then
  notify-send "Theme" "gsettings is not available" -t 3000
  exit 1
fi

current="$(gsettings get "$schema" color-scheme 2>/dev/null || true)"
if [ "$current" = "'prefer-dark'" ]; then
  gsettings set "$schema" color-scheme 'prefer-light'
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
  notify-send "Theme" "Light mode enabled" -t 2000
else
  gsettings set "$schema" color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
  notify-send "Theme" "Dark mode enabled" -t 2000
fi
