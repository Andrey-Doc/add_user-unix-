#!/bin/bash

# User Management Script
# Features: better error handling, logging, security, and additional options

set -euo pipefail

# Configuration
CONFIG_FILE="/etc/user_manager.conf"
USERS_FILE="users_list.txt"
GROUPS_FILE="groups_list.txt"
BACKUP_DIR="/var/backups/user_management"
LOG_FILE="/var/log/user_management.log"
LOCK_FILE="/var/run/user_manager.lock"
PASSWORD_LENGTH=16
DEFAULT_SHELL="/bin/bash"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize required files and directories
init_setup() {
    mkdir -p "$(dirname "$LOG_FILE")" "$BACKUP_DIR"
    touch "$LOG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# User Management Configuration
DEFAULT_UMASK=0022
PASSWORD_EXPIRE_DAYS=90
MIN_UID=1000
MAX_UID=60000
CREATE_HOME=yes
SKEL_DIR=/etc/skel
EOF
    fi
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Check prerequisites
check_dependencies() {
    local dependencies=("awk" "getent" "useradd" "groupadd" "passwd" "openssl")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error_exit "Dependency $dep not found"
        fi
    done
}

# Acquire lock to prevent concurrent execution
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null; then
            error_exit "Another instance is already running (PID: $pid)"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Release lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Generate secure random password
generate_password() {
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c "$PASSWORD_LENGTH"
}

# Validate username
validate_username() {
    local username=$1
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1
    fi
    if [[ ${#username} -gt 32 ]]; then
        return 1
    fi
    return 0
}

# Backup current state
backup_state() {
    local backup_file="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$backup_file" /etc/passwd /etc/group /etc/shadow /etc/gshadow 2>/dev/null || true
    log "INFO" "System state backed up to $backup_file"
}

# Create groups from file
create_groups() {
    if [[ ! -f "$GROUPS_FILE" ]]; then
        log "WARN" "Groups file $GROUPS_FILE not found"
        return 0
    fi

    local count=0
    while IFS= read -r group; do
        group=$(echo "$group" | xargs)
        [[ -z "$group" || "$group" =~ ^# ]] && continue

        if getent group "$group" >/dev/null; then
            log "INFO" "Group '$group' already exists"
        else
            if groupadd "$group"; then
                log "INFO" "Created group: $group"
                ((count++))
            else
                log "ERROR" "Failed to create group: $group"
            fi
        fi
    done < "$GROUPS_FILE"
    
    log "INFO" "Created $count groups"
}

# Create users from file
create_users() {
    if [[ ! -f "$USERS_FILE" ]]; then
        error_exit "Users file $USERS_FILE not found"
    fi

    local count=0
    while IFS=: read -r username groups comment; do
        username=$(echo "$username" | xargs)
        [[ -z "$username" || "$username" =~ ^# ]] && continue

        if ! validate_username "$username"; then
            log "ERROR" "Invalid username: $username"
            continue
        fi

        if getent passwd "$username" >/dev/null; then
            log "WARN" "User '$username' already exists"
            continue
        fi

        # Create user
        local useradd_cmd=("useradd")
        useradd_cmd+=("-m")
        useradd_cmd+=("-s" "$DEFAULT_SHELL")
        
        [[ -n "$comment" ]] && useradd_cmd+=("-c" "$comment")
        
        if "${useradd_cmd[@]}" "$username"; then
            # Set password
            local password=$(generate_password)
            echo "$username:$password" | chpasswd
            if [[ $? -eq 0 ]]; then
                log "INFO" "Created user: $username with generated password"
                echo "Username: $username Password: $password" >> "$BACKUP_DIR/passwords_$(date +%Y%m%d).txt"
            else
                log "ERROR" "Failed to set password for: $username"
            fi

            # Add to groups
            if [[ -n "$groups" ]]; then
                IFS=',' read -ra group_array <<< "$groups"
                for group in "${group_array[@]}"; do
                    group=$(echo "$group" | xargs)
                    if getent group "$group" >/dev/null; then
                        usermod -a -G "$group" "$username"
                        log "INFO" "Added user $username to group $group"
                    else
                        log "WARN" "Group $group not found for user $username"
                    fi
                done
            fi

            # Set password expiration
            chage -M "$PASSWORD_EXPIRE_DAYS" "$username"
            ((count++))
        else
            log "ERROR" "Failed to create user: $username"
        fi
    done < "$USERS_FILE"
    
    log "INFO" "Created $count users"
}

# Set secure permissions
secure_permissions() {
    chmod 600 "$BACKUP_DIR/passwords_"*.txt 2>/dev/null || true
    chmod 644 "$LOG_FILE"
    chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

# Cleanup function
cleanup() {
    release_lock
    secure_permissions
}

# Main execution
main() {
    trap cleanup EXIT ERR INT TERM

    echo -e "${BLUE}=== Enhanced User Management Script ===${NC}"
    
    acquire_lock
    init_setup
    load_config
    check_dependencies
    
    log "INFO" "Starting user management process"
    
    # Backup current state
    backup_state
    
    # Create groups first
    echo -e "${YELLOW}Creating groups...${NC}"
    create_groups
    
    # Then create users
    echo -e "${YELLOW}Creating users...${NC}"
    create_users
    
    log "INFO" "User management process completed successfully"
    echo -e "${GREEN}Operation completed successfully!${NC}"
    echo -e "${YELLOW}Passwords stored in: $BACKUP_DIR/passwords_$(date +%Y%m%d).txt${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -u|--users)
            USERS_FILE="$2"
            shift 2
            ;;
        -g|--groups)
            GROUPS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -c, --config FILE    Configuration file"
            echo "  -u, --users FILE     Users file"
            echo "  -g, --groups FILE    Groups file"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

# Run main function
main
