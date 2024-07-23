#!/bin/bash

LOG_FILE="/var/log/devopsfetch.log"
TEMP_DIR="/tmp/devopsfetch"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_command_exists() {
    command -v "$1" &> /dev/null
}

check_and_install_dependencies() {
    dependencies=("net-tools" "jq" "nginx")
    for dep in "${dependencies[@]}"; do
        if ! check_command_exists "$dep"; then
            log "$dep not found. Installing..."
            apt-get install -y "$dep" &>> "$LOG_FILE" || log "Failed to install $dep."
        else
            log "$dep is already installed."
        fi
    done
    
    if ! check_command_exists "docker"; then
        log "docker not found. Installing..."
        apt-get remove -y docker docker-engine docker.io containerd runc &>> "$LOG_FILE" || log "Failed to remove old docker versions."
        apt-get update &>> "$LOG_FILE" || log "Failed to update package list."
        apt-get install -y ca-certificates curl gnupg &>> "$LOG_FILE" || log "Failed to install dependencies for Docker."
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || log "Failed to download Docker GPG key."
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update &>> "$LOG_FILE" || log "Failed to update package list."
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin &>> "$LOG_FILE" || log "Failed to install Docker."
    else
        log "docker is already installed."
    fi
}

confirm_installation() {
    if [[ "$1" != "-y" ]]; then
        read -p "This will install and configure devopsfetch. Do you wish to proceed? (y/n) " response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                echo "Proceeding with interactive installation."
                log "Proceeding with installation."
                ;;
            *)
                echo "Installation aborted."
                log "Installation aborted."
                exit 0
                ;;
        esac
    else
        echo "Proceeding with automatic installation due to -y flag."
        log "Proceeding with installation due to -y flag."
    fi
}

cleanup() {
    log "Performing cleanup..."

    # Remove temporary files created during installation
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log "Removed temporary directory $TEMP_DIR."
    fi

    # Clean up APT cache
    apt-get clean
    log "Cleaned up APT cache."

    log "Cleanup completed."
}

# Initial Echo Statement
echo "Starting devopsfetch installation..."

# Root Check and Early Exit
echo "EUID: $EUID"
if [[ $EUID -ne 0 ]]; then
    echo "Permission denied: Please run as root or with elevated privileges (sudo)."
    exit 1
else
    echo "Root check passed. Proceeding with installation..."
fi

# Logging After Root Check
log "Root check: $EUID"
log "Permission check passed. Proceeding with installation..."

# Check for unsupported flags and prompt to use -y
if [[ "$1" != "" && "$1" != "-y" ]]; then
    echo "Unsupported flag detected. Please use the -y flag for installation."
    log "Unsupported flag detected. Installation aborted."
    exit 1
fi

# Confirm installation
confirm_installation "$1"

# Display progress message
progress_message() {
    local steps=("Copying devopsmainfetch script" "Setting up log rotation" "Creating systemd service" "Starting devopsfetch service")
    echo "Installation in progress, please wait..."
    sleep 3
    local step_index=0
    while true; do
        echo -n "${steps[$step_index]}..."
        sleep 2.5
        echo -ne "\r"
        step_index=$(( (step_index + 1) % ${#steps[@]} ))
    done
}

# Start progress message in background
progress_message &

# Store the PID of the progress message function
progress_pid=$!

# Update package list and log output
apt-get update &>> "$LOG_FILE" || { log "Failed to update package list. Continuing with installation."; }

# Install dependencies and log output
check_and_install_dependencies

# Copy devopsmainfetch script to /usr/local/bin and make it executable
cp devopsmainfetch.sh /usr/local/bin/devopsfetch &>> "$LOG_FILE" || log "Failed to copy devopsmainfetch script."
chmod +x /usr/local/bin/devopsfetch &>> "$LOG_FILE" || log "Failed to make devopsfetch script executable."

# Create log file and set permissions
touch /var/log/devopsfetch.log &>> "$LOG_FILE" || log "Failed to create log file."
chmod 644 /var/log/devopsfetch.log &>> "$LOG_FILE" || log "Failed to set log file permissions."

# Set up log rotation
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
systemctl daemon-reload &>> "$LOG_FILE" || log "Failed to reload systemd."
systemctl enable devopsfetch.service &>> "$LOG_FILE" || log "Failed to enable devopsfetch service."
systemctl start devopsfetch.service &>> "$LOG_FILE" || log "Failed to start devopsfetch service."

log "Systemd service started"


# Display completion message with usage hint
echo -e "\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
echo -e "Installation completed! Use 'devopsfetch' to run the tool. E.g sudo devopsfetch -d"
echo -e "View Detailed logs in /var/log/devopsfetch.log"
echo -e "For detailed usage instructions, refer to the documentation: https://github.com/laraadeboye/devopsfetch/wiki"
echo -e "For help, enter: sudo devopsfetch --help."
echo -e "\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
log "Installation completed."

# Stop the progress message
kill $progress_pid
wait $progress_pid 2>/dev/null

# Perform cleanup
cleanup
