#!/bin/bash

LOG_FILE="/var/log/devopsfetch-setup.log"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    log "Permission denied: Please run as root."
    exit 1
fi

log "Starting setup for testing devopsfetch..."

# Update and upgrade the system
log "Updating and upgrading the system..."
apt-get update && apt-get upgrade -y

# Install necessary packages
log "Installing necessary packages..."
apt-get install -y net-tools jq nginx docker.io

# Ensure Docker is running
log "Ensuring Docker is running..."
systemctl start docker
systemctl enable docker

# Create test Docker images and containers
log "Creating test Docker images and containers..."
docker run -d --name test_container1 -p 8081:80 nginx
docker run -d --name test_container2 -p 8082:80 nginx

# Create Nginx configuration files
log "Creating Nginx configuration files..."
cat << EOF > /etc/nginx/conf.d/test1.conf
server {
    listen 80;
    server_name test1.local;
    location / {
        proxy_pass http://localhost:8081;
    }
}
EOF

cat << EOF > /etc/nginx/conf.d/test2.conf
server {
    listen 80;
    server_name test2.local;
    location / {
        proxy_pass http://localhost:8082;
    }
}
EOF

# Reload Nginx to apply the new configurations
log "Reloading Nginx..."
systemctl reload nginx

# Create test users
log "Creating test users..."
useradd -m user1
useradd -m user2
useradd -m user3

# Simulate last login times
log "Simulating last login times for users..."
lastlog -u user1 -t 0
lastlog -u user2 -t 0
lastlog -u user3 -t 0

# Display final setup status
log "Setup completed. The system is ready for testing devopsfetch."

# Optionally, display system information for verification
log "System Information:"
log "Users: $(getent passwd | grep /home | cut -d: -f1)"
log "Docker Containers: $(docker ps --format "table {{.Names}}\t{{.Ports}}")"
log "Nginx Configs: $(ls /etc/nginx/conf.d/)"

log "You can now proceed to test the devopsfetch script."
