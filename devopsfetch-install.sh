#!/bin/bash

LOG_FILE="/var/log/devopsfetch-install.log"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_command_exists() {
    command -v "$1" &> /dev/null
}

check_and_install_dependencies() {
    dependencies=("net-tools" "jq" "nginx" "docker.io")
    for dep in "${dependencies[@]}"; do
        if ! check_command_exists "$dep"; then
            log "$dep not found. Installing..."
            apt-get install -y "$dep" || { log "Failed to install $dep."; exit 1; }
        else
            log "$dep is already installed."
        fi
    done
}

confirm_installation() {
    if [[ "$1" != "-y" ]]; then
        read -p "This will install and configure devopsfetch. Do you wish to proceed? (y/n) " response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                log "Proceeding with installation."
                ;;
            *)
                log "Installation aborted."
                exit 0
                ;;
        esac
    else
        log "Proceeding with installation due to -y flag."
    fi
}

cleanup() {
    log "Performing cleanup..."
    # Add any cleanup steps if needed
}

log "Starting devopsfetch installation..."

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    log "Permission denied: Please run as root."
    exit 1
fi

# Confirm installation
confirm_installation "$1"

# Update package list
log "Updating package list..."
apt-get update || { log "Failed to update package list."; exit 1; }

# Install dependencies
log "Checking and installing dependencies..."
check_and_install_dependencies

# Copy devopsfetch script to /usr/local/bin and make it executable
log "Copying devopsfetch script..."
cp devopsfetch.sh /usr/local/bin/devopsfetch || { log "Failed to copy devopsfetch script."; exit 1; }
chmod +x /usr/local/bin/devopsfetch || { log "Failed to make devopsfetch script executable."; exit 1; }

# Create log file
log "Creating log file..."
touch /var/log/devopsfetch.log || { log "Failed to create log file."; exit 1; }
chmod 644 /var/log/devopsfetch.log || { log "Failed to set log file permissions."; exit 1; }

# Set up log rotation
log "Setting up log rotation..."
cat << EOF > /etc/logrotate.d/devopsfetch
/var/log/devopsfetch.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 root root
}
EOF

# Create systemd service file
log "Creating systemd service..."
cat << EOF > /etc/systemd/system/devopsfetch.service
[Unit]
Description=Devopsfetch Service
After=network.target

[Service]
ExecStart=/usr/local/bin/devopsfetch
StandardOutput=journal
StandardError=journal
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
log "Reloading systemd and enabling devopsfetch service..."
systemctl daemon-reload || { log "Failed to reload systemd."; exit 1; }
systemctl enable devopsfetch.service || { log "Failed to enable devopsfetch service."; exit 1; }
systemctl start devopsfetch.service || { log "Failed to start devopsfetch service."; exit 1; }

log "Installation completed."

# Cleanup
cleanup
