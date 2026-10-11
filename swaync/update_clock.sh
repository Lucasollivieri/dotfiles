#!/usr/bin/env bash

BASE_CONFIG="$HOME/.config/swaync/config.json"
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/swaync"
RUNTIME_CONFIG="$RUN_DIR/config.json"
INTERVAL=15
LAST_RX=0
LAST_TX=0

command -v jq >/dev/null 2>&1 || exit 1
mkdir -p "$RUN_DIR"

sum_net_bytes() {
    local direction="$1" total=0 stats_file
    for stats_file in /sys/class/net/*/statistics/${direction}_bytes; do
        [ -r "$stats_file" ] || continue
        case "$stats_file" in /sys/class/net/lo/*) continue ;; esac
        total=$((total + $(<"$stats_file")))
    done
    printf '%s\n' "$total"
}

format_rate() {
    local kb="$1"
    if [ "$kb" -ge 1024 ]; then
        awk -v kb="$kb" 'BEGIN {printf "%.1f MB/s", kb / 1024}'
    else
        printf '%s KB/s' "$kb"
    fi
}

cpu_usage() {
    local a b
    a=$(awk '/^cpu / {print $2+$3+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
    sleep 0.1
    b=$(awk '/^cpu / {print $2+$3+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
    awk -v a="$a" -v b="$b" 'BEGIN {split(a,x); split(b,y); if (y[2]-x[2] > 0) printf "%d", 100*(y[1]-x[1])/(y[2]-x[2]); else print 0}'
}

update_time() {
    [ -f "$RUNTIME_CONFIG" ] || cp "$BASE_CONFIG" "$RUNTIME_CONFIG"
    [ "$BASE_CONFIG" -nt "$RUNTIME_CONFIG" ] && cp "$BASE_CONFIG" "$RUNTIME_CONFIG"

    local user host uptime updates cpu ram disk rx tx down up net header tmp
    user="${USER:-$(id -un)}"
    host="$(cat /etc/hostname 2>/dev/null | cut -d. -f1)"
    [ -n "$host" ] || host="localhost"
    uptime="$(uptime -p | sed 's/up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/; s/,//g')"
    if command -v checkupdates >/dev/null 2>&1; then
        updates="$(checkupdates 2>/dev/null | wc -l)"
    else
        updates="--"
    fi
    cpu="$(cpu_usage)"
    ram="$(free | awk '/Mem:/ {printf "%d", $3/$2*100}')"
    disk="$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
    rx="$(sum_net_bytes rx)"
    tx="$(sum_net_bytes tx)"

    if [ "$LAST_RX" -gt 0 ] && [ "$LAST_TX" -gt 0 ]; then
        down=$(( (rx - LAST_RX) / INTERVAL / 1024 ))
        up=$(( (tx - LAST_TX) / INTERVAL / 1024 ))
        net="↓$(format_rate "$down") ↑$(format_rate "$up")"
    else
        net="↓0 KB/s ↑0 KB/s"
    fi
    LAST_RX=$rx
    LAST_TX=$tx

    header="󰀄  ${user}@${host}\n󰥔  Uptime: ${uptime}  ·  Updates: ${updates}"
    if [ "$updates" = "--" ]; then
        header="󰀄  ${user}@${host}\n󰥔  Uptime: ${uptime}  ·  Updates: unavailable"
    fi
    tmp=$(mktemp -p "$RUN_DIR" tmp.XXXXXX) || return 1
    jq --arg h "$header" --arg cpu "CPU\n${cpu}%" --arg ram "RAM\n${ram}%" --arg disk "DISK\n${disk}%" --arg net "NET\n${net}" \
      '."widget-config"["label#header"].text = $h
       | ."widget-config"["buttons-grid#sysinfo-grid"].actions[0].label = $cpu
       | ."widget-config"["buttons-grid#sysinfo-grid"].actions[1].label = $ram
       | ."widget-config"["buttons-grid#sysinfo-grid"].actions[2].label = $disk
       | ."widget-config"["buttons-grid#sysinfo-grid"].actions[3].label = $net' \
      "$RUNTIME_CONFIG" > "$tmp" && mv "$tmp" "$RUNTIME_CONFIG" && swaync-client --reload-config
}

update_time
while true; do sleep "$INTERVAL"; update_time; done
