#!/usr/bin/env bash
set -euo pipefail

THEME_ID="${1:-}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$ROOT/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop-themes"
CURRENT="$STATE_DIR/current"
LOG="$STATE_DIR/apply.log"
mkdir -p "$STATE_DIR"

failures=()
need() { command -v "$1" >/dev/null 2>&1; }

load_theme() {
  local file="$THEME_DIR/$THEME_ID.theme"
  [ -r "$file" ] || { echo "Theme not found: $THEME_ID" >&2; exit 2; }
  unset name description background surface surface_alt text text_muted border accent accent_hover selected success warning error is_dark
  # Theme files are repository-controlled key=value data, not shell commands.
  while IFS='=' read -r key value; do
    [ -z "$key" ] || [[ "$key" == \#* ]] || printf -v "$key" '%s' "$value"
  done < "$file"
}

hex_to_rasi() { printf '%s' "$1"; }

render_rofi() {
  cat > "$ROOT/rofi/colors.rasi" <<EOF
* {
    bg:             $background;
    bg-highlight:   $surface_alt;
    fg:             $text;
    muted:          $text_muted;
    teal:           $accent;
    teal-bright:    $accent_hover;
    border-color:   $border;
    inactive:       $surface_alt;
    red:            $error;
    background:     @bg;
    background-alt: @bg-highlight;
    foreground:     @fg;
    selected:       @teal;
    active:         @teal-bright;
    urgent:         @red;
    border:         @border-color;
}
EOF
}

render_waybar() {
  cat > "$ROOT/waybar/colors/colors.css" <<EOF
@define-color bg0 $background;
@define-color bg1 $surface;
@define-color bg2 $surface_alt;
@define-color bg3 $border;
@define-color bg4 $text_muted;
@define-color red $error;
@define-color orange $warning;
@define-color green $success;
@define-color yellow $warning;
@define-color green1 $accent;
@define-color aqua $accent_hover;
@define-color blue $accent;
@define-color blue1 $accent;
@define-color blue2 $accent_hover;
@define-color purple $accent;
@define-color offwhite $text;
@define-color white $text;
@define-color fg $text;
@define-color grey0 $text_muted;
@define-color grey1 $text_muted;
@define-color grey2 $text_muted;
EOF
}

render_kitty() {
  cat > "$ROOT/kitty/colors.conf" <<EOF
background $background
foreground $text
cursor $accent_hover
cursor_text_color $background
selection_background $surface_alt
selection_foreground $text
url_color $accent_hover
active_border_color $accent
inactive_border_color $border
tab_bar_background $background
active_tab_foreground $background
active_tab_background $accent
inactive_tab_foreground $text
inactive_tab_background $surface
color0 $background
color8 $border
color1 $error
color9 $error
color2 $success
color10 $success
color3 $warning
color11 $warning
color4 $accent
color12 $accent_hover
color5 $accent
color13 $accent_hover
color6 $accent
color14 $accent_hover
color7 $text
color15 $text
EOF
}

render_swaync_tokens() {
  cat > "$ROOT/swaync/themes/current.css" <<EOF
@define-color bg_main $background;
@define-color card $surface;
@define-color card_alt $surface_alt;
@define-color accent $accent;
@define-color accent_light $accent_hover;
@define-color text_main $text;
@define-color text_secondary $text_muted;
@define-color border $border;
@define-color inactive $surface_alt;
@define-color danger $error;
EOF
  sed -i 's#@import "themes/abyssal-teal.css";#@import "themes/current.css";#' "$ROOT/swaync/style.css"
}

apply_gtk() {
  if need gsettings; then
    if [ "$is_dark" = true ]; then
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark || failures+=(gsettings-color)
      gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || failures+=(gtk-theme)
    else
      gsettings set org.gnome.desktop.interface color-scheme prefer-light || failures+=(gsettings-color)
      gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3 || failures+=(gtk-theme)
    fi
    gsettings set org.gnome.desktop.interface icon-theme kora-icons || failures+=(icons)
    gsettings set org.gnome.desktop.interface cursor-theme Bibata-Material-Noir || failures+=(cursor)
    gsettings set org.gnome.desktop.interface cursor-size 24 || failures+=(cursor-size)
  else failures+=(gsettings); fi
}

load_theme
render_rofi
render_waybar
render_kitty
render_swaync_tokens
apply_gtk
printf '%s\n' "$THEME_ID" > "$CURRENT"
printf '%s theme=%s failures=%s\n' "$(date -Is)" "$THEME_ID" "${failures[*]:-none}" >> "$LOG"

swaync-client -R >/dev/null 2>&1 || failures+=(swaync-reload)
hyprctl reload >/dev/null 2>&1 || failures+=(hypr-reload)
pkill -USR1 kitty >/dev/null 2>&1 || true
pkill -SIGUSR2 waybar >/dev/null 2>&1 || true
notify-send "Theme applied" "$name — $description" -t 2500 || true
[ "${#failures[@]}" -eq 0 ] || { printf 'Warnings: %s\n' "${failures[*]}" >&2; exit 1; }
