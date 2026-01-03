#!/bin/sh

# Load configuration
CONFIG_FILE="$(dirname "$0")/ap-config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found!"
    echo "Please copy ap-config.conf.sample to ap-config.conf and customize it."
    exit 1
fi

# Source the configuration file
. "$CONFIG_FILE"

# Build list of all APs
ALL_APS=""
for var in $(grep "^AP_" "$CONFIG_FILE" | cut -d= -f1); do
    eval "ip=\$$var"
    ALL_APS="$ALL_APS $ip"
done

download_configs() {
    local selected_aps="${1:-$ALL_APS}"
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        echo "Downloading config from $AP_NAME ($AP)..."
        mkdir -p "./data/$AP_NAME"
        scp -rO root@$AP:/etc/config/* "./data/$AP_NAME/"
        sleep 5
    done
}

upload_configs() {
    local selected_aps="${1:-$ALL_APS}"
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        scp -rO ./data/$AP_NAME/* root@$AP:/etc/config/
        sleep 1
    done
}

reload_configs() {
    local selected_aps="${1:-$ALL_APS}"
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        echo "Reloading config on $AP_NAME ($AP)..."
        ssh root@$AP "/sbin/reload_config"
        sleep 1
    done
}

setup_ssh_keys() {
    local selected_aps="${1:-$ALL_APS}"
    
    # Check if SSH key exists, create if not
    if [ ! -f ~/.ssh/id_ed25519.pub ]; then
        echo "Generating SSH key..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "ap-config-automation"
    fi
    
    # Copy key to selected APs
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        echo "=== Setting up passwordless SSH for $AP_NAME ($AP) ==="
        ssh-copy-id -o StrictHostKeyChecking=no root@$AP
        sleep 1
    done
    
    echo "SSH key setup complete!"
    read -p "Press Enter to continue..."
}

# AP selection menu
select_aps() {
    local selected=""
    local cmd="dialog --clear --checklist 'Select APs (Space to select, Enter to confirm)' 15 50 $(($(grep -c '^AP_' "$CONFIG_FILE") + 1))"
    
    # Dynamically build checklist from config file
    for var in $(grep "^AP_" "$CONFIG_FILE" | cut -d= -f1); do
        eval "ip=\$$var"
        name=$(echo "$var" | sed 's/AP_//')
        cmd="$cmd $name '$ip' ON"
    done
    cmd="$cmd ALL 'All APs' OFF"
    cmd="$cmd 3>&1 1>&2 2>&3"
    
    selected=$(eval $cmd)
    
    if echo "$selected" | grep -q "ALL"; then
        echo "$ALL_APS"
    else
        local result=""
        for var in $(grep "^AP_" "$CONFIG_FILE" | cut -d= -f1); do
            name=$(echo "$var" | sed 's/AP_//')
            eval "ip=\$$var"
            echo "$selected" | grep -q "$name" && result="$result $ip"
        done
        echo "$result"
    fi
}

# Main menu
while true; do
    choice=$(dialog --clear --menu "AP Config Manager" 15 50 3 \
        1 "Download configs" \
        2 "Upload configs" \
        3 "Setup SSH keys" \
        3>&1 1>&2 2>&3)
    
    clear
    case $choice in
        1)
            SELECTED_APS=$(select_aps)
            if [ -n "$SELECTED_APS" ]; then
                download_configs "$SELECTED_APS"
            fi
            ;;
        2)
            SELECTED_APS=$(select_aps)
            if [ -n "$SELECTED_APS" ]; then
                upload_configs "$SELECTED_APS"
                
                if dialog --clear --yesno "Run /sbin/reload_config on selected APs?" 10 50 3>&1 1>&2 2>&3; then
                    clear
                    reload_configs "$SELECTED_APS"
                fi
            fi
            ;;
        3)
            SELECTED_APS=$(select_aps)
            if [ -n "$SELECTED_APS" ]; then
                clear
                setup_ssh_keys "$SELECTED_APS"
            fi
            ;;
        *) break ;;
    esac
done

clear
