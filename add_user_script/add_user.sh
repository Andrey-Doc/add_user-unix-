#!/bin/bash

# Enhanced User Management Script with user deletion menu
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
TEMP_MENU="/tmp/user_manager_menu.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
REMOVE_HOME_ON_DELETE=yes
REMOVE_MAIL_SPOOL=yes
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
    local dependencies=("awk" "getent" "useradd" "groupadd" "passwd" "openssl" "whiptail")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error_exit "Dependency $dep not found. Please install it."
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
    echo -e "${GREEN}Successfully created $count groups${NC}"
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
    echo -e "${GREEN}Successfully created $count users${NC}"
}

# Get list of all regular users (non-system)
get_all_users() {
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | sort
}

# Get user information
get_user_info() {
    local username=$1
    echo -e "${CYAN}User information: ${GREEN}$username${NC}"
    echo -e "UID: $(id -u "$username")"
    echo -e "GID: $(id -g "$username")"
    echo -e "Groups: $(id -Gn "$username")"
    echo -e "Home directory: $(getent passwd "$username" | cut -d: -f6)"
    echo -e "Shell: $(getent passwd "$username" | cut -d: -f7)"
    echo -e "Last login: $(lastlog -u "$username" | awk 'NR==2 {print $4" "$5" "$6" "$7" "$8" "$9}')"
}

# Delete user with confirmation
delete_user() {
    local username=$1
    
    if ! getent passwd "$username" >/dev/null; then
        echo -e "${RED}User $username does not exist!${NC}"
        return 1
    fi

    # Show user info
    get_user_info "$username"
    echo

    # Confirmation
    read -p "Are you sure you want to delete user $username? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Deletion cancelled.${NC}"
        return 0
    fi

    # Determine delete options
    local userdel_cmd=("userdel")
    if [[ "$REMOVE_HOME_ON_DELETE" == "yes" ]]; then
        userdel_cmd+=("-r")
    fi
    if [[ "$REMOVE_MAIL_SPOOL" == "yes" ]]; then
        userdel_cmd+=("--remove")
    fi

    # Delete user
    if "${userdel_cmd[@]}" "$username"; then
        log "INFO" "Deleted user: $username"
        echo -e "${GREEN}User $username successfully deleted.${NC}"
        
        # Remove from groups
        local groups=$(id -Gn "$username" 2>/dev/null || true)
        if [[ -n "$groups" ]]; then
            for group in $groups; do
                if [[ "$group" != "$username" ]]; then
                    gpasswd -d "$username" "$group" 2>/dev/null || true
                fi
            done
        fi
        
        return 0
    else
        log "ERROR" "Failed to delete user: $username"
        echo -e "${RED}Error deleting user $username${NC}"
        return 1
    fi
}

# Interactive menu for user deletion
user_deletion_menu() {
    local users=()
    local options=()
    
    # Get all regular users
    mapfile -t users < <(get_all_users)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No users available for deletion.${NC}"
        return 0
    fi

    # Create options array for whiptail
    for i in "${!users[@]}"; do
        options+=("$i" "${users[$i]}" "OFF")
    done

    # Show menu using whiptail
    local selected_users=$(whiptail --title "User Deletion" \
        --checklist "Select users to delete:" \
        20 60 10 \
        "${options[@]}" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 || -z "$selected_users" ]]; then
        echo -e "${YELLOW}Deletion cancelled.${NC}"
        return 0
    fi

    # Process selected users
    local deleted_count=0
    for selection in $selected_users; do
        local index=$(echo "$selection" | tr -d '"')
        local username="${users[$index]}"
        
        if delete_user "$username"; then
            ((deleted_count++))
        fi
        echo
    done

    echo -e "${GREEN}Deleted users: $deleted_count${NC}"
}

# Text-based user selection menu (fallback if whiptail fails)
text_based_deletion_menu() {
    local users=()
    mapfile -t users < <(get_all_users)
    
    if [[ ${#users[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No users available for deletion.${NC}"
        return 0
    fi

    echo -e "${CYAN}Available users:${NC}"
    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done

    echo
    read -p "Enter user numbers to delete (comma-separated, or 'all'): " selection

    if [[ -z "$selection" ]]; then
        echo -e "${YELLOW}Deletion cancelled.${NC}"
        return 0
    fi

    local deleted_count=0
    if [[ "$selection" == "all" ]]; then
        for username in "${users[@]}"; do
            if delete_user "$username"; then
                ((deleted_count++))
            fi
            echo
        done
    else
        IFS=',' read -ra indices <<< "$selection"
        for index in "${indices[@]}"; do
            index=$((index-1))
            if [[ $index -ge 0 && $index -lt ${#users[@]} ]]; then
                if delete_user "${users[$index]}"; then
                    ((deleted_count++))
                fi
                echo
            else
                echo -e "${RED}Invalid selection: $((index+1))${NC}"
            fi
        done
    fi

    echo -e "${GREEN}Deleted users: $deleted_count${NC}"
}

# Show main menu
show_main_menu() {
    while true; do
        echo -e "${BLUE}=== User Management Menu ===${NC}"
        echo -e "1. Create users and groups from files"
        echo -e "2. Delete users"
        echo -e "3. Show all users"
        echo -e "4. Show user information"
        echo -e "5. Exit"
        echo -n "Select option (1-5): "
        
        read choice
        case $choice in
            1)
                echo -e "${YELLOW}Creating users and groups...${NC}"
                create_groups
                create_users
                ;;
            2)
                echo -e "${YELLOW}Opening user deletion menu...${NC}"
                if command -v whiptail >/dev/null; then
                    user_deletion_menu
                else
                    text_based_deletion_menu
                fi
                ;;
            3)
                echo -e "${CYAN}List of all users:${NC}"
                get_all_users | nl -w 3 -s '. '
                ;;
            4)
                echo -n "Enter username: "
                read username
                if getent passwd "$username" >/dev/null; then
                    get_user_info "$username"
                else
                    echo -e "${RED}User $username does not exist!${NC}"
                fi
                ;;
            5)
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid selection. Please try again.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        clear
    done
}

# Set secure permissions
secure_permissions() {
    chmod 600 "$BACKUP_DIR/passwords_"*.txt 2>/dev/null || true
    chmod 644 "$LOG_FILE"
    chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

# Cleanup function
cleanup() {
    rm -f "$TEMP_MENU" 2>/dev/null || true
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
    
    # Show main menu
    show_main_menu
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
        -a|--auto)
            # Automated mode without menu
            log "INFO" "Starting automated user management process"
            backup_state
            create_groups
            create_users
            log "INFO" "Automated process completed successfully"
            echo -e "${GREEN}Automated operation completed successfully!${NC}"
            echo -e "${YELLOW}Passwords stored in: $BACKUP_DIR/passwords_$(date +%Y%m%d).txt${NC}"
            exit 0
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -c, --config FILE    Configuration file"
            echo "  -u, --users FILE     Users file"
            echo "  -g, --groups FILE    Groups file"
            echo "  -a, --auto           Run in automated mode (no menu)"
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
