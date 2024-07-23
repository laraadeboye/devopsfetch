#!/bin/bash

LOG_FILE="/var/log/devopsmainfetch.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to display help
display_help() {
    cat << EOF
Usage: $0 [option] [argument]

Options:
  -p, --port [port_number]     Display all active ports and services or detailed information about a specific port.
  -d, --docker [container_name] List all Docker images and containers or detailed information about a specific container.
  -n, --nginx [domain]         Display all Nginx domains and their ports or detailed configuration information for a specific domain.
  -u, --users [username]       List all users and their last login times or detailed information about a specific user.
  -t, --time [time_range]      Display activities within a specified time range.
  -h, --help                   Display this help and exit.
EOF
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check permissions
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log "Permission denied: Please run as root."
        exit 1
    fi
}

# Function to display active ports and services
show_ports() {
    if [ -z "$1" ]; then
        netstat -tuln | awk 'NR>2 {print $1, $4, $7}' | column -t | awk '{printf "%-10s %-25s %-30s\n", $1, $2, $3}'
    else
        netstat -tuln | grep ":$1 " | awk '{print $1, $4, $7}' | column -t | awk '{printf "%-10s %-25s %-30s\n", $1, $2, $3}'
    fi
}

# Function to display Docker images and containers
show_docker() {
    if [ -z "$1" ]; then
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ImageID}}\t{{.CreatedAt}}\t{{.Size}}"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.ID}}\t{{.Status}}\t{{.Ports}}"
    else
        docker inspect "$1" | jq '.'
    fi
}

# Function to display Nginx domains and ports
show_nginx() {
    config_dirs=("/etc/nginx/sites-available" "/etc/nginx/conf.d")
    for dir in "${config_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ -z "$1" ]; then
                grep -E 'server_name|listen' "$dir"/* | awk '{print $2, $3}' | column -t | awk '{printf "%-25s %-15s\n", $1, $2}'
            else
                grep -A 10 "server_name $1;" "$dir"/* | column -t
            fi
        fi
    done
}

# Function to display users and last login times
show_users() {
    if [ -z "$1" ]; then
        last | head -n -2 | column -t | awk '{printf "%-20s %-20s %-20s %-30s\n", $1, $3, $4, $5 " " $6 " " $7 " " $8 " " $9}'
    else
        user_info=$(getent passwd "$1")
        if [ -z "$user_info" ]; then
            log "User $1 not found."
            echo "User $1 not found."
            exit 1
        fi

        echo "Detailed information for user: $1"
        echo "==================================="
        last "$1" | column -t | awk '{printf "%-20s %-20s %-20s %-30s\n", $1, $3, $4, $5 " " $6 " " $7 " " $8 " " $9}'
        echo ""
        id "$1" | awk '{printf "%-20s %-20s %-20s\n", "UID: " $1, "GID: " $2, "Groups: " $3}'
        echo ""
        echo "$user_info" | awk -F: '{printf "%-20s %-20s\n", "Home Directory: ", $6}'
    fi
}

# Function to display activities within a specified time range
show_time_range() {
    journalctl --since "$1" | column -t
}

# Main function to handle options
main() {
    check_permissions
    case "$1" in
        -p|--port)
            show_ports "$2"
            ;;
        -d|--docker)
            command_exists docker || { log "Docker command not found."; exit 1; }
            show_docker "$2"
            ;;
        -n|--nginx)
            command_exists nginx || { log "Nginx command not found."; exit 1; }
            show_nginx "$2"
            ;;
        -u|--users)
            show_users "$2"
            ;;
        -t|--time)
            show_time_range "$2"
            ;;
        -h|--help)
            display_help
            ;;
        *)
            log "Invalid option: $1"
            display_help
            exit 1
            ;;
    esac
}

main "$@"
