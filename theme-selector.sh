#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$ROOT/themes"

items=()
while IFS= read -r file; do
  [ -f "$file" ] || continue
  id="${file##*/}"; id="${id%.theme}"
  name="$(sed -n 's/^name=//p' "$file")"
  desc="$(sed -n 's/^description=//p' "$file")"
  items+=("$id — $name — $desc")
done < <(find "$THEME_DIR" -maxdepth 1 -type f -name '*.theme' -print | sort)

[ "${#items[@]}" -gt 0 ] || exit 1
choice="$(printf '%s\n' "${items[@]}" | rofi -dmenu -i -p 'Select Theme' -format s)"
[ -n "$choice" ] || exit 0
id="${choice%% — *}"
exec "$ROOT/theme-manager.sh" "$id"
