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

# Git commit helper for data directory
git_commit_data() {
    local message="$1"
    cd "./data" || return
    
    # Initialize git if not already done
    if [ ! -d ".git" ]; then
        git init
        git config user.name "AP Config Manager"
        git config user.email "ap-config@local"
    fi
    
    # Add and commit changes
    git add -A
    if git diff --cached --quiet; then
        echo "No changes to commit"
    else
        git commit -m "$message"
        echo "Changes committed to local git"
    fi
    cd ..
}

download_configs() {
    local selected_aps="${1:-$ALL_APS}"
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        echo "Downloading config from $AP_NAME ($AP)..."
        mkdir -p "./data/$AP_NAME/etc/config"
        scp -rO root@$AP:/etc/config/* "./data/$AP_NAME/etc/config/"
        sleep 5
    done
    
    # Commit changes to git
    git_commit_data "Downloaded configs from: $(echo $selected_aps | tr ' ' ',')"
}

download_startup_scripts() {
    local selected_aps="${1:-$ALL_APS}"
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        echo "Downloading startup scripts from $AP_NAME ($AP)..."
        mkdir -p "./data/$AP_NAME/etc/init.d"
        
        # Download rc.local if it exists
        ssh root@$AP "[ -f /etc/rc.local ] && cat /etc/rc.local" > "./data/$AP_NAME/etc/rc.local" 2>/dev/null
        
        # Download custom startup scripts from /etc/init.d/
        ssh root@$AP "ls /etc/init.d/custom_* 2>/dev/null" | while read script; do
            if [ -n "$script" ]; then
                script_name=$(basename "$script")
                scp -O root@$AP:"$script" "./data/$AP_NAME/etc/init.d/$script_name" 2>/dev/null
            fi
        done
        
        sleep 2
    done
    
    # Commit changes to git
    git_commit_data "Downloaded startup scripts from: $(echo $selected_aps | tr ' ' ',')"
}

upload_startup_scripts() {
    local selected_aps="${1:-$ALL_APS}"
    
    # Commit current state before upload
    git_commit_data "Before uploading startup scripts to: $(echo $selected_aps | tr ' ' ',')"
    
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        echo "Uploading startup scripts to $AP_NAME ($AP)..."
        
        # Upload rc.local if it exists
        if [ -f "./data/$AP_NAME/etc/rc.local" ]; then
            scp -O "./data/$AP_NAME/etc/rc.local" root@$AP:/etc/rc.local
            ssh root@$AP "chmod +x /etc/rc.local"
        fi

        if [ -d "./data/$AP_NAME/etc/init.d" ]; then            
            # Upload custom init scripts
            for script in ./data/$AP_NAME/etc/init.d/custom_*; do
                if [ -f "$script" ]; then
                    script_name=$(basename "$script")
                    scp -O "$script" root@$AP:/etc/init.d/"$script_name"
                    ssh root@$AP "chmod +x /etc/init.d/$script_name && /etc/init.d/$script_name enable"
                fi
            done
        fi
        sleep 1
    done
    
    # Commit after successful upload
    git_commit_data "Uploaded startup scripts to: $(echo $selected_aps | tr ' ' ',')"
}

reboot_aps() {
    local selected_aps="${1:-$ALL_APS}"
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        echo "Rebooting $AP_NAME ($AP)..."
        ssh root@$AP "reboot" &
        sleep 1
    done
    echo "Reboot commands sent to all selected APs"
    sleep 10
    read -p "Press Enter to continue..."
}

upload_configs() {
    local selected_aps="${1:-$ALL_APS}"
    
    # Commit current state before upload
    git_commit_data "Before upload to: $(echo $selected_aps | tr ' ' ',')"
    
    for AP in $selected_aps; do
        AP_NAME=$(grep "^AP_.*=$AP" "$CONFIG_FILE" | cut -d= -f1 | sed 's/AP_//')
        scp -rO ./data/$AP_NAME/etc/config/* root@$AP:/etc/config/
        sleep 1
    done
    
    # Commit after successful upload
    git_commit_data "Uploaded configs to: $(echo $selected_aps | tr ' ' ',')"
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
    choice=$(dialog --clear --menu "AP Config Manager" 20 60 8 \
        1 "Download configs" \
        2 "Upload configs" \
        3 "Setup SSH keys" \
        4 "Download startup scripts" \
        5 "Upload startup scripts" \
        6 "Reboot selected APs" \
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
        4)
            SELECTED_APS=$(select_aps)
            if [ -n "$SELECTED_APS" ]; then
                download_startup_scripts "$SELECTED_APS"
            fi
            ;;
        5)
            SELECTED_APS=$(select_aps)
            if [ -n "$SELECTED_APS" ]; then
                upload_startup_scripts "$SELECTED_APS"                
            fi
            ;;
        6)
            SELECTED_APS=$(select_aps)
            if [ -n "$SELECTED_APS" ]; then
                if dialog --clear --yesno "Are you sure you want to reboot the selected APs?" 10 50 3>&1 1>&2 2>&3; then
                    clear
                    reboot_aps "$SELECTED_APS"
                fi
            fi
            ;;
        *) break ;;
    esac
done

clear
