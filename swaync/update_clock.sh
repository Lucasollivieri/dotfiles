#!/usr/bin/env bash

BASE_CONFIG="$HOME/.config/swaync/config.json"
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/swaync"
RUNTIME_CONFIG="$RUN_DIR/config.json"
INTERVAL=15
LAST_RX=0
LAST_TX=0

command -v jq >/dev/null 2>&1 || exit 1

mkdir -p "$RUN_DIR"

if [ ! -f "$RUNTIME_CONFIG" ] || [ "$BASE_CONFIG" -nt "$RUNTIME_CONFIG" ]; then
    cp "$BASE_CONFIG" "$RUNTIME_CONFIG"
fi

sum_net_bytes() {
    local direction="$1"
    local total=0
    local stats_file

    for stats_file in /sys/class/net/*/statistics/${direction}_bytes; do
        [ -r "$stats_file" ] || continue
        case "$stats_file" in
            /sys/class/net/lo/*) continue ;;
        esac
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

update_time() {
    # If base dotfile was updated, re-sync runtime copy
    if [ "$BASE_CONFIG" -nt "$RUNTIME_CONFIG" ]; then
        cp "$BASE_CONFIG" "$RUNTIME_CONFIG"
    fi

    CURRENT_TIME=$(date +"%H:%M")
    CURRENT_DATE=$(date +"%A, %B %d")

    CPU=$(awk '/^cpu / {u=$2+$3+$4;t=$2+$3+$4+$5+$6+$7+$8;if(NR==1){u1=u;t1=t;}else{print int((u-u1)/(t-t1)*100)}}' /proc/stat <(sleep 0.1; awk '/^cpu /' /proc/stat))
    
    RAM=$(free | awk '/Mem:/ {print int($3/$2 * 100)}')
    UPTIME=$(uptime -p | sed 's/up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/; s/,//g')

    RX=$(sum_net_bytes rx)
    TX=$(sum_net_bytes tx)
    if [ "$LAST_RX" -gt 0 ] && [ "$LAST_TX" -gt 0 ]; then
        DOWN=$(( (RX - LAST_RX) / INTERVAL / 1024 ))
        UP=$(( (TX - LAST_TX) / INTERVAL / 1024 ))
        NET="↓$(format_rate "$DOWN") ↑$(format_rate "$UP")"
    else
        NET="↓0 KB/s ↑0 KB/s"
    fi
    LAST_RX=$RX
    LAST_TX=$TX

    CPU_STR="CPU
${CPU}%"
    RAM_STR="RAM
${RAM}%"
    NET_STR="NET
${NET}"
    UPTIME_STR="UPTIME
${UPTIME}"

    TMP_FILE=$(mktemp -p "$RUN_DIR" tmp.XXXXXX) || return 1

    jq --arg t "$CURRENT_TIME" --arg d "$CURRENT_DATE" \
       --arg cpu "$CPU_STR" --arg ram "$RAM_STR" --arg net "$NET_STR" --arg uptime "$UPTIME_STR" \
       '.["widget-config"]["label#clock"].text = $t
        | .["widget-config"]["label#date"].text = $d
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[0].label = $cpu
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[1].label = $ram
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[2].label = $net
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[3].label = $uptime' \
       "$RUNTIME_CONFIG" > "$TMP_FILE" && mv "$TMP_FILE" "$RUNTIME_CONFIG" && swaync-client --reload-config
}

# Run once initially
update_time

while true; do
    sleep "$INTERVAL"
    update_time
done
