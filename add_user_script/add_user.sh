#!/bin/bash

# User Management Script with interactive user creation
# Version 2.0

# Configuration
CONFIG_FILE="/etc/user_manager.conf"
BACKUP_DIR="/var/backups/user_management"
LOG_FILE="/var/log/user_management.log"
LOCK_FILE="/var/lock/user_manager.lock"
PASSWORD_FILE="$BACKUP_DIR/passwords_$(date +%Y%m%d).txt"

# Default settings
DEFAULT_UMASK=0022
PASSWORD_EXPIRE_DAYS=90
MIN_UID=1000
MAX_UID=60000
CREATE_HOME="yes"
SKEL_DIR="/etc/skel"
REMOVE_HOME_ON_DELETE="yes"
REMOVE_MAIL_SPOOL="yes"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize
init_directories() {
    mkdir -p "$BACKUP_DIR"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_success() {
    log "SUCCESS: $1"
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    log "ERROR: $1"
    echo -e "${RED}✗ $1${NC}" >&2
}

log_info() {
    log "INFO: $1"
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Backup system files
backup_system_files() {
    log_info "Backing up system files..."
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    cp /etc/passwd "$BACKUP_DIR/passwd.backup.$timestamp"
    cp /etc/group "$BACKUP_DIR/group.backup.$timestamp"
    cp /etc/shadow "$BACKUP_DIR/shadow.backup.$timestamp"
    cp /etc/gshadow "$BACKUP_DIR/gshadow.backup.$timestamp"
    
    log_success "System files backed up to $BACKUP_DIR"
}

# Generate random password
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | cut -c1-16
}

# Create group
create_group() {
    local groupname=$1
    if grep -q "^$groupname:" /etc/group; then
        log_info "Group $groupname already exists"
        return 0
    fi
    
    if groupadd "$groupname" 2>/dev/null; then
        log_success "Group $groupname created successfully"
        return 0
    else
        log_error "Failed to create group $groupname"
        return 1
    fi
}

# Create user
create_user() {
    local username=$1
    local groups=$2
    local comment=$3
    local home_dir=$4
    
    if id "$username" &>/dev/null; then
        log_error "User $username already exists"
        return 1
    fi
    
    local useradd_cmd="useradd"
    local home_option=""
    
    if [ -n "$home_dir" ]; then
        home_option="-d $home_dir"
    fi
    
    if [ "$CREATE_HOME" = "yes" ]; then
        useradd_cmd="$useradd_cmd -m"
    fi
    
    if [ -n "$comment" ]; then
        useradd_cmd="$useradd_cmd -c \"$comment\""
    fi
    
    useradd_cmd="$useradd_cmd -s /bin/bash $home_option $username"
    
    if eval "$useradd_cmd"; then
        # Set password
        local password=$(generate_password)
        echo "$username:$password" | chpasswd
        
        # Set password expiration
        chage -M "$PASSWORD_EXPIRE_DAYS" "$username"
        
        # Add to groups
        if [ -n "$groups" ]; then
            IFS=',' read -ra group_array <<< "$groups"
            for group in "${group_array[@]}"; do
                if usermod -a -G "$group" "$username"; then
                    log_info "Added $username to group $group"
                fi
            done
        fi
        
        # Save password
        echo "$username:$password" >> "$PASSWORD_FILE"
        chmod 600 "$PASSWORD_FILE"
        
        log_success "User $username created successfully"
        echo -e "${YELLOW}Password for $username: $password${NC}"
        return 0
    else
        log_error "Failed to create user $username"
        return 1
    fi
}

# Interactive user creation
create_user_interactive() {
    while true; do
        # Get username
        username=$(whiptail --inputbox "Enter username:" 8 40 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return 1
        fi
        
        if [ -z "$username" ]; then
            whiptail --msgbox "Username cannot be empty!" 8 40
            continue
        fi
        
        if id "$username" &>/dev/null; then
            whiptail --msgbox "User $username already exists!" 8 40
            continue
        fi
        
        # Get comment (full name)
        comment=$(whiptail --inputbox "Enter full name (comment):" 8 40 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return 1
        fi
        
        # Get home directory
        home_dir=$(whiptail --inputbox "Enter home directory (leave empty for default):" 8 60 "/home/$username" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return 1
        fi
        
        if [ -z "$home_dir" ]; then
            home_dir="/home/$username"
        fi
        
        # Get groups
        all_groups=$(getent group | cut -d: -f1 | sort | tr '\n' ' ')
        groups=$(whiptail --inputbox "Enter groups (comma-separated):\n\nAvailable groups: $all_groups" 12 60 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            return 1
        fi
        
        # Confirm
        whiptail --yesno "Create user with these settings?\n\nUsername: $username\nFull name: $comment\nHome directory: $home_dir\nGroups: $groups" 12 60
        if [ $? -eq 0 ]; then
            break
        fi
    done
    
    # Create user
    if create_user "$username" "$groups" "$comment" "$home_dir"; then
        whiptail --msgbox "User $username created successfully!\n\nPassword has been generated and saved to $PASSWORD_FILE" 12 60
        return 0
    else
        whiptail --msgbox "Failed to create user $username!" 8 40
        return 1
    fi
}

# Get all regular users
get_all_users() {
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'
}

# Show user information
show_user_info() {
    local username=$1
    if ! id "$username" &>/dev/null; then
        log_error "User $username does not exist"
        return 1
    fi
    
    local user_info=$(getent passwd "$username")
    local user_id=$(id -u "$username")
    local group_id=$(id -g "$username")
    local groups=$(id -Gn "$username")
    local home_dir=$(echo "$user_info" | cut -d: -f6)
    local shell=$(echo "$user_info" | cut -d: -f7)
    local comment=$(echo "$user_info" | cut -d: -f5)
    
    whiptail --msgbox "User Information: $username

User ID: $user_id
Group ID: $group_id
Groups: $groups
Home directory: $home_dir
Shell: $shell
Full name: $comment" 16 60
}

# Delete user
delete_user() {
    local username=$1
    if ! id "$username" &>/dev/null; then
        log_error "User $username does not exist"
        return 1
    fi
    
    whiptail --yesno "Are you sure you want to delete user $username?" 8 40
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local remove_home=""
    if [ "$REMOVE_HOME_ON_DELETE" = "yes" ]; then
        whiptail --yesno "Remove home directory for $username?" 8 40
        if [ $? -eq 0 ]; then
            remove_home="-r"
        fi
    fi
    
    if userdel $remove_home "$username"; then
        log_success "User $username deleted successfully"
        whiptail --msgbox "User $username deleted successfully!" 8 40
        return 0
    else
        log_error "Failed to delete user $username"
        whiptail --msgbox "Failed to delete user $username!" 8 40
        return 1
    fi
}

# Interactive user deletion
delete_user_interactive() {
    local users=()
    while IFS= read -r user; do
        users+=("$user" "" "OFF")
    done < <(get_all_users)
    
    if [ ${#users[@]} -eq 0 ]; then
        whiptail --msgbox "No regular users found!" 8 40
        return 1
    fi
    
    local selected_users=$(whiptail --title "Delete Users" --checklist \
        "Select users to delete:" 20 60 10 "${users[@]}" 3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ] || [ -z "$selected_users" ]; then
        return 1
    fi
    
    selected_users=$(echo "$selected_users" | tr -d '"')
    IFS=' ' read -ra users_to_delete <<< "$selected_users"
    
    for user in "${users_to_delete[@]}"; do
        delete_user "$user"
    done
}

# Main menu
main_menu() {
    while true; do
        choice=$(whiptail --title "User Management" --menu \
            "Choose an option:" 16 60 7 \
            "1" "Create users and groups from files" \
            "2" "Create user interactively" \
            "3" "Delete users" \
            "4" "Show all users" \
            "5" "Show user information" \
            "6" "Backup system files" \
            "7" "Exit" 3>&1 1>&2 2>&3)
        
        case $choice in
            1)
                # Create from files (existing functionality)
                ;;
            2)
                create_user_interactive
                ;;
            3)
                delete_user_interactive
                ;;
            4)
                users_list=$(get_all_users | tr '\n' ' ')
                whiptail --msgbox "All regular users:\n\n$users_list" 16 60
                ;;
            5)
                username=$(whiptail --inputbox "Enter username:" 8 40 3>&1 1>&2 2>&3)
                if [ $? -eq 0 ] && [ -n "$username" ]; then
                    show_user_info "$username"
                fi
                ;;
            6)
                backup_system_files
                whiptail --msgbox "System files backed up successfully!" 8 40
                ;;
            7)
                log_info "Script terminated by user"
                exit 0
                ;;
            *)
                exit 0
                ;;
        esac
    done
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_info "Configuration loaded from $CONFIG_FILE"
    fi
}

# Acquire lock
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        log_error "Another instance is already running"
        exit 1
    fi
    echo $$ > "$LOCK_FILE"
}

# Release lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Cleanup on exit
cleanup() {
    release_lock
    log_info "Script execution completed"
}

# Main execution
main() {
    trap cleanup EXIT
    acquire_lock
    check_root
    init_directories
    load_config
    backup_system_files
    
    if [ "$1" = "--auto" ]; then
        # Automated mode (existing functionality)
        :
    else
        main_menu
    fi
}

# Handle command line arguments
case "$1" in
    "--help" | "-h")
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  --auto     Run in automated mode"
        echo "  --help     Show this help"
        echo "  --interactive  Run in interactive mode (default)"
        ;;
    "--auto")
        main --auto
        ;;
    *)
        main
        ;;
esac
