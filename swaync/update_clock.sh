#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/swaync/config.json"

update_time() {
    CURRENT_TIME=$(date +"%I:%M%p")
    CURRENT_DATE=$(date +"%A, %B %d")

    # Read current values in config
    OLD_TIME=$(jq -r '.["widget-config"]["label#clock"].text' "$CONFIG_FILE" 2>/dev/null)
    OLD_DATE=$(jq -r '.["widget-config"]["label#date"].text' "$CONFIG_FILE" 2>/dev/null)

    if [[ "$CURRENT_TIME" != "$OLD_TIME" || "$CURRENT_DATE" != "$OLD_DATE" ]]; then
        TMP_FILE=$(mktemp)
        jq --arg t "$CURRENT_TIME" --arg d "$CURRENT_DATE" \
           '.["widget-config"]["label#clock"].text = $t | .["widget-config"]["label#date"].text = $d' \
           "$CONFIG_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CONFIG_FILE"
        
        swaync-client --reload-config
    fi
}

# Run once initially
update_time

# Loop every 15 seconds to check for minute changes
while true; do
    update_time
    sleep 15
done
