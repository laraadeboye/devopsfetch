#!/bin/bash

LOG_FILE="/var/log/devopsmainfetch.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
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
  -t, --time <start_date> [end_date] Display activities within a specified time range. If only one date is provided, it will display activities for that day.
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
        log "Permission denied: Please run as root or with sudo."
        exit 1
    fi
}

# Function to display active ports and services
show_ports() {
    if [[ -z "$1" ]]; then
        echo "Protocol      Local Address             PID/Program"
        netstat -tuln | awk 'NR>2 {print $1, $4, $7}' | column -t | awk '{printf "%-10s %-25s %-30s\n", $1, $2, $3}'
    else
        echo "Protocol      Local Address             PID/Program"
        netstat -tuln | grep ":$1 " | awk '{print $1, $4, $7}' | column -t | awk '{printf "%-10s %-25s %-30s\n", $1, $2, $3}'
    fi
}

# Function to display Docker images and containers
show_docker() {
    if [[ -z "$1" ]]; then
        echo "Docker Images:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | column -t
        echo ""
        echo "Docker Containers:"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.ID}}\t{{.Status}}\t{{.Ports}}" | column -t
    else
        docker inspect "$1" | jq '.'
    fi
}


show_nginx() {
    config_dirs=("/etc/nginx/sites-available" "/etc/nginx/conf.d")
    echo "Nginx Configuration:"
    echo "------------------------------------------------------------------"
    printf "%-25s %-10s %-30s %-30s\n" "Domain" "Port" "Proxy" "Configuration File"
    echo "------------------------------------------------------------------"

    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for file in "$dir"/*; do
                domain=$(grep -E '^\s*server_name\s+' "$file" | awk '{print $2}')
                port=$(grep -E '^\s*listen\s+' "$file" | awk '{print $2}')
                proxy=$(grep -E '^\s*proxy_pass\s+' "$file" | awk '{print $2}')
                if [[ -n "$domain" || -n "$port" || -n "$proxy" ]]; then
                    printf "%-25s %-10s %-30s %-30s\n" "$domain" "$port" "$proxy" "$file"
                fi
            done
        fi
    done
}

# Function to display users and last login times
show_users() {
    if [[ -z "$1" ]]; then
        echo "Users and Last Login Times:"
        echo "Username              TTY                  From                 Login Time"
        echo "--------------------  ------------------  ------------------  ----------------------------------"
        last | head -n -2 | column -t | awk '{printf "%-20s %-20s %-20s %-30s\n", $1, $3, $4, $5 " " $6 " " $7 " " $8 " " $9}'
    else
        user_info=$(getent passwd "$1")
        if [[ -z "$user_info" ]]; then
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
    if [[ $# -eq 1 ]]; then
        start_date="$1"
        end_date="$1"
    elif [[ $# -eq 2 ]]; then
        start_date="$1"
        end_date="$2"
    else
        echo "Usage: $0 --time <start_date> [end_date]"
        return 1
    fi

    journal_output=$(journalctl --since "$start_date" --until "$end_date" --output-fields=__REALTIME_TIMESTAMP,_PID,_COMM,MESSAGE --output=short-iso --no-pager)
    
    if [[ -z "$journal_output" ]]; then
        echo "No entries found for the specified date range: $start_date to $end_date"
        return 0
    fi

    echo "$journal_output" | awk '
        BEGIN {
            printf "%-25s %-10s %-20s %-50s\n", "Date", "PID", "Command", "Message"
        }
        {
            date = $1 "T" $2
            pid = $3
            command = $4
            message_start = index($0, $5)
            message = substr($0, message_start)
            printf "%-25s %-10s %-20s %-50s\n", date, pid, command, message
        }
    '
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
            if [[ -z "$2" ]]; then
                echo "Usage: $0 --time <start_date> [end_date]"
                exit 1
            elif [[ -z "$3" ]]; then
                show_time_range "$2"
            else
                show_time_range "$2" "$3"
            fi
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            log "Invalid option: $1"
            display_help
            exit 1
            ;;
    esac
}

main "$@"
