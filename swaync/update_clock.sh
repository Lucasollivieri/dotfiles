#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/swaync/config.json"
LAST_RX=0
LAST_TX=0

update_time() {
    CURRENT_TIME=$(date +"%H:%M")
    CURRENT_DATE=$(date +"%A, %B %d")

    # Calculate CPU usage (accurate 100ms sample)
    CPU=$(awk '{u=$2+$3+$4;t=$2+$3+$4+$5+$6+$7+$8;if(NR==1){u1=u;t1=t;}else{print int((u-u1)/(t-t1)*100);}}' <(grep 'cpu ' /proc/stat) <(sleep 0.1; grep 'cpu ' /proc/stat))
    
    RAM=$(free | awk '/Mem:/ {print int($3/$2 * 100)}')
    UPTIME=$(uptime -p | sed 's/up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/; s/,//g')

    TEMP=$(awk '{printf "%dC", $1 / 1000}' /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 1)
    [ -z "$TEMP" ] && TEMP="--"

    RX=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | awk '{sum += $1} END {print sum + 0}')
    TX=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | awk '{sum += $1} END {print sum + 0}')
    if [ "$LAST_RX" -gt 0 ] && [ "$LAST_TX" -gt 0 ]; then
        DOWN=$(( (RX - LAST_RX) / 15 / 1024 ))
        if [ "$DOWN" -ge 1024 ]; then
            DOWN_MB=$(awk -v d="$DOWN" 'BEGIN {printf "%.1f", d/1024}')
            NET="↓${DOWN_MB} MB/s"
        else
            NET="↓${DOWN} KB/s"
        fi
    else
        NET="↓0 KB/s"
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

    TMP_FILE=$(mktemp -p "$(dirname "$CONFIG_FILE")")
    jq --arg t "$CURRENT_TIME" --arg d "$CURRENT_DATE" \
       --arg cpu "$CPU_STR" --arg ram "$RAM_STR" --arg net "$NET_STR" --arg uptime "$UPTIME_STR" \
       '.["widget-config"]["label#clock"].text = $t
        | .["widget-config"]["label#date"].text = $d
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[0].label = $cpu
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[1].label = $ram
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[2].label = $net
        | .["widget-config"]["buttons-grid#sysinfo-grid"].actions[3].label = $uptime' \
       "$CONFIG_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CONFIG_FILE"
    
    swaync-client --reload-config
}

# Run once initially
update_time

# Loop every 15 seconds to check for updates
while true; do
    update_time
    sleep 15
done
