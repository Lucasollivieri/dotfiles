#!/usr/bin/env bash

# Check if Bluetooth is currently blocked (OFF)
if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
    # Bluetooth is OFF: turn it ON
    rfkill unblock bluetooth
fi

# Function to check if bluetooth controller is responsive
is_bt_ready() {
    ls /sys/class/bluetooth/hci* &>/dev/null && timeout 2 bluetoothctl show &>/dev/null
}

# If bluetooth controller is not responsive, reset it automatically
if ! is_bt_ready; then
    notify-send "Bluetooth" "Inicializando adaptador UGreen..." -t 3000
    
    # Try systemctl reset service first
    sudo systemctl start reset-ugreen-bluetooth.service 2>/dev/null || sudo usbreset 0a12:0001 2>/dev/null
    
    # Wait up to 5 seconds for controller to appear
    for i in {1..10}; do
        if is_bt_ready; then
            break
        fi
        sleep 0.5
    done
fi

# Launch blueman-manager
blueman-manager &

