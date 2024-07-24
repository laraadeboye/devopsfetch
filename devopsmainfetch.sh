#!/bin/bash

LOG_FILE="/var/log/devopsfetch.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}


# Function to display help
display_help() {
    cat << EOF
Usage: $0 [option] [argument]

================================================================================
| Option                       | Description                                  |
================================================================================
| -p, --port [port_number]     | Display all active ports and services or     |
|                              | detailed information about a specific port.  |
--------------------------------------------------------------------------------
| -d, --docker [container_name]| List all Docker images and containers or     |
|                              | detailed information about a specific        |
|                              | container.                                   |
--------------------------------------------------------------------------------
| -n, --nginx [domain]         | Display all Nginx domains and their ports or |
|                              | detailed configuration information for a     |
|                              | specific domain.                             |
--------------------------------------------------------------------------------
| -u, --users [username]       | List all users and their last login times or |
|                              | detailed information about a specific user.  |
--------------------------------------------------------------------------------
| -t, --time <start_date>      | Display activities within a specified time   |
| [end_date]                   | range. If only one date is provided, it will |
|                              | display activities for that day.             |
--------------------------------------------------------------------------------
| -h, --help                   | Display this help and exit.                  |
================================================================================
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

# Function to display active ports, services, and users
show_ports() {
    local header="Protocol      Port         PID/Program                   User"
    local separator="========== ============ =============================== ======================="

    if [[ -z "$1" ]]; then
        echo "$header"
        echo "$separator"
        netstat -tulnp | awk 'NR>2 {print $1, $4, $7}' | while read -r protocol local_address pid_program; do
            port=$(echo "$local_address" | awk -F: '{print $NF}')
            pid=$(echo "$pid_program" | cut -d'/' -f1)
            user=$(ps -o user= -p "$pid" 2>/dev/null)
            printf "%-10s %-12s %-30s %-22s\n" "$protocol" "$port" "$pid_program" "$user"
        done
    else
        echo "$header"
        echo "$separator"
        netstat -tulnp | grep ":$1 " | awk '{print $1, $4, $7}' | while read -r protocol local_address pid_program; do
            port=$(echo "$local_address" | awk -F: '{print $NF}')
            pid=$(echo "$pid_program" | cut -d'/' -f1)
            user=$(ps -o user= -p "$pid" 2>/dev/null)
            printf "%-10s %-12s %-30s %-22s\n" "$protocol" "$port" "$pid_program" "$user"
        done
    fi
}


# Function to display Docker images and containers
show_docker() {
    local image_header="REPOSITORY              | TAG                 | IMAGE ID            | CREATED AT                      | SIZE"
    local container_header="NAMES                   | IMAGE               | CONTAINER ID        | STATUS                          | PORTS"
    local separator="=======================|===================|===================|============================|============="

    if [[ -z "$1" ]]; then
        echo "Docker Images:"
        echo "$image_header"
        echo "$separator"
        docker images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | awk -F'\t' '{printf "%-25s | %-20s | %-20s | %-30s | %-15s\n", $1, $2, $3, $4, $5}'
        echo ""
        echo "Docker Containers:"
        echo "$container_header"
        echo "$separator"
        docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.ID}}\t{{.Status}}\t{{.Ports}}" | awk -F'\t' '{printf "%-30s | %-25s | %-20s | %-30s | %-20s\n", $1, $2, $3, $4, $5}'
    else
        docker inspect "$1" | jq '.'
    fi
}


# show_nginx() {
#     config_dirs=("/etc/nginx/sites-available" "/etc/nginx/conf.d")
#     echo "Nginx Configuration:"
#     echo "------------------------------------------------------------------"
#     printf "%-25s %-10s %-30s %-30s\n" "Domain" "Port" "Proxy" "Configuration File"
#     echo "------------------------------------------------------------------"

#     for dir in "${config_dirs[@]}"; do
#         if [[ -d "$dir" ]]; then
#             for file in "$dir"/*; do
#                 domain=$(grep -E '^\s*server_name\s+' "$file" | awk '{print $2}')
#                 port=$(grep -E '^\s*listen\s+' "$file" | awk '{print $2}')
#                 proxy=$(grep -E '^\s*proxy_pass\s+' "$file" | awk '{print $2}')
#                 if [[ -n "$domain" || -n "$port" || -n "$proxy" ]]; then
#                     printf "%-25s %-10s %-30s %-30s\n" "$domain" "$port" "$proxy" "$file"
#                 fi
#             done
#         fi
#     done
# }

show_nginx() {
    config_dirs=("/etc/nginx/sites-available" "/etc/nginx/conf.d")
    
    
    {
        echo "Nginx Configuration:"
        echo "============================================================================================="
        printf "%-30s | %-30s | %-50s\n" "Server Domain" "Proxy" "Configuration File"
        echo "---------------------------------------------------------------------------------------------"

        for dir in "${config_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                found=false
                for file in "$dir"/*; do
                    if [[ -f "$file" ]]; then
                        while read -r line; do
                            domain=$(echo "$line" | grep -E '^\s*server_name\s+' | awk '{print $2}')
                            proxy=$(echo "$line" | grep -E '^\s*proxy_pass\s+' | awk '{print $2}')
                            if [[ -n "$domain" || -n "$proxy" ]]; then
                                printf "%-30s | %-30s | %-50s\n" "$domain" "$proxy" "$file"
                                found=true
                            fi
                        done < "$file"
                    else
                        echo "Error: Configuration file $file not found." >> "$LOG_FILE"
                    fi
                done
                
                if [[ "$found" == false ]]; then
                    echo "No relevant configuration found in directory: $dir" >> "$LOG_FILE"
                fi
            else
                echo "Error: Directory $dir does not exist." >> "$$LOG_FILE"
            fi
        done
    } 2>> "$$LOG_FILE"
}


# Function to display users, last login, TTY, UID, GID, and Groups
show_users() {
    local header="USERNAME              LAST LOGIN              TTY                   UID       GID       GROUPS"
    local separator="====================  ======================  ====================  ========  ========  ===================="

    echo "User Sessions:"
    echo "$header"
    echo "$separator"
    
    # Retrieve and format user session data
    who | awk '{print $1, $2, $3, $4, $5}' | while IFS=' ' read -r user tty date time rest; do
        # Format date and time into last login
        last_login=$(date -d "$date $time" +"%Y-%m-%d %H:%M:%S")

        # Get UID, GID, and Groups
        uid=$(id -u "$user")
        gid=$(id -g "$user")
        groups=$(id -Gn "$user" | tr ' ' ',')

        printf "%-20s %-22s %-20s %-8s %-8s %-s\n" "$user" "$last_login" "$tty" "$uid" "$gid" "$groups"
    done
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

    echo "Date         | PID        | Command              | Message"
    echo "============ | ========== | ==================== | =================================================="

    echo "$journal_output" | awk '
        BEGIN {
            FS=" "; OFS=" | "
        }
        {
            date = substr($1, 1, 10)  # Extract only the date part
            pid = $3
            command = $4
            message_start = index($0, $5)
            message = substr($0, message_start)
            printf "%-12s | %-10s | %-20s | %-s\n", date, pid, command, message
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
            log "Invalid option detected: $1"
            echo -e "\nYou have entered an invalid option: $1\n"
            display_help
            exit 1
            ;;
    esac
}

main "$@"
