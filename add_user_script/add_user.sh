#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/user_manager.log"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Colored output function
print_status() {
    case $1 in
        success) echo -e "${GREEN}[SUCCESS]${NC} $2" ;;
        error) echo -e "${RED}[ERROR]${NC} $2" ;;
        warning) echo -e "${YELLOW}[WARNING]${NC} $2" ;;
        info) echo -e "${BLUE}[INFO]${NC} $2" ;;
    esac
}

# Sudo privileges check
check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        print_status error "This script must be run as root or with sudo privileges"
        exit 1
    fi
}

# User creation function
create_user() {
    echo
    print_status info "=== CREATE NEW USER ==="
    
    read -p "Enter username: " username
    
    # Check if user exists
    if id "$username" &>/dev/null; then
        print_status error "User $username already exists"
        return 1
    fi
    
    # Password input and validation
    while true; do
        read -s -p "Enter password: " password
        echo
        read -s -p "Confirm password: " password_confirm
        echo
        
        if [ "$password" != "$password_confirm" ]; then
            print_status error "Passwords do not match"
            continue
        fi
        
        if [ ${#password} -lt 8 ]; then
            print_status warning "Password must be at least 8 characters long"
            continue
        fi
        
        break
    done
    
    # Create user
    if useradd -m -s /bin/bash "$username" 2>/dev/null; then
        print_status success "User $username created"
    else
        print_status error "Error creating user"
        return 1
    fi
    
    # Set password
    echo "$username:$password" | chpasswd 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status success "Password set successfully"
    else
        print_status error "Error setting password"
    fi
    
    # Create SSH directory
    mkdir -p "/home/$username/.ssh"
    touch "/home/$username/.ssh/authorized_keys"
    chmod 700 "/home/$username/.ssh"
    chmod 600 "/home/$username/.ssh/authorized_keys"
    chown -R "$username:$username" "/home/$username/.ssh"
    
    print_status success "SSH directory configured"
    
    # Set basic permissions
    setup_user_permissions "$username" "user"
    
    log_message "Created user: $username"
    print_status success "User $username successfully created and configured"
}

# Copy user settings function
copy_user_settings() {
    echo
    print_status info "=== COPY USER SETTINGS ==="
    
    read -p "Enter source username: " source_user
    read -p "Enter target username: " target_user
    
    # Check if users exist
    if ! id "$source_user" &>/dev/null; then
        print_status error "Source user $source_user does not exist"
        return 1
    fi
    
    if ! id "$target_user" &>/dev/null; then
        print_status error "Target user $target_user does not exist"
        return 1
    fi
    
    if [ "$source_user" = "$target_user" ]; then
        print_status error "Source and target users cannot be the same"
        return 1
    fi
    
    echo
    echo "Select settings to copy:"
    echo "1) SSH configuration (keys, config)"
    echo "2) Shell environment (.bashrc, .profile)"
    echo "3) Vim/Editor configuration"
    echo "4) Git configuration"
    echo "5) All of the above"
    echo "0) Cancel"
    
    read -p "Select option [0-5]: " settings_choice
    
    case $settings_choice in
        1) copy_ssh_settings "$source_user" "$target_user" ;;
        2) copy_shell_settings "$source_user" "$target_user" ;;
        3) copy_editor_settings "$source_user" "$target_user" ;;
        4) copy_git_settings "$source_user" "$target_user" ;;
        5) copy_all_settings "$source_user" "$target_user" ;;
        0) 
            print_status info "Operation cancelled"
            return
            ;;
        *)
            print_status error "Invalid selection"
            return 1
            ;;
    esac
}

# Copy SSH settings
copy_ssh_settings() {
    local source_user=$1
    local target_user=$2
    
    local source_ssh_dir="/home/$source_user/.ssh"
    local target_ssh_dir="/home/$target_user/.ssh"
    
    if [ ! -d "$source_ssh_dir" ]; then
        print_status warning "No SSH directory found for source user"
        return 1
    fi
    
    # Create backup of target directory
    if [ -d "$target_ssh_dir" ]; then
        backup_dir="/tmp/ssh_backup_$target_user_$(date +%s)"
        mkdir -p "$backup_dir"
        cp -r "$target_ssh_dir"/* "$backup_dir/" 2>/dev/null
        print_status info "Backup created in $backup_dir"
    fi
    
    # Copy SSH files
    mkdir -p "$target_ssh_dir"
    cp -r "$source_ssh_dir"/* "$target_ssh_dir/" 2>/dev/null
    
    # Set correct permissions
    chmod 700 "$target_ssh_dir"
    chmod 600 "$target_ssh_dir"/*
    chown -R "$target_user:$target_user" "$target_ssh_dir"
    
    print_status success "SSH settings copied from $source_user to $target_user"
    log_message "SSH settings copied from $source_user to $target_user"
}

# Copy shell settings
copy_shell_settings() {
    local source_user=$1
    local target_user=$2
    
    local source_home="/home/$source_user"
    local target_home="/home/$target_user"
    
    # List of shell configuration files to copy
    shell_files=(
        ".bashrc" ".profile" ".bash_profile" ".bash_logout"
        ".zshrc" ".zprofile" ".inputrc" ".screenrc"
        ".tmux.conf" ".selected_editor"
    )
    
    for file in "${shell_files[@]}"; do
        if [ -f "$source_home/$file" ]; then
            cp "$source_home/$file" "$target_home/$file" 2>/dev/null
            chown "$target_user:$target_user" "$target_home/$file" 2>/dev/null
            chmod 644 "$target_home/$file" 2>/dev/null
        fi
    done
    
    print_status success "Shell settings copied from $source_user to $target_user"
    log_message "Shell settings copied from $source_user to $target_user"
}

# Copy editor settings
copy_editor_settings() {
    local source_user=$1
    local target_user=$2
    
    local source_home="/home/$source_user"
    local target_home="/home/$target_user"
    
    # Vim configuration
    if [ -d "$source_home/.vim" ]; then
        cp -r "$source_home/.vim" "$target_home/" 2>/dev/null
        chown -R "$target_user:$target_user" "$target_home/.vim" 2>/dev/null
    fi
    
    # Vimrc file
    if [ -f "$source_home/.vimrc" ]; then
        cp "$source_home/.vimrc" "$target_home/.vimrc" 2>/dev/null
        chown "$target_user:$target_user" "$target_home/.vimrc" 2>/dev/null
    fi
    
    # Nano configuration
    if [ -f "$source_home/.nanorc" ]; then
        cp "$source_home/.nanorc" "$target_home/.nanorc" 2>/dev/null
        chown "$target_user:$target_user" "$target_home/.nanorc" 2>/dev/null
    fi
    
    print_status success "Editor settings copied from $source_user to $target_user"
    log_message "Editor settings copied from $source_user to $target_user"
}

# Copy git settings
copy_git_settings() {
    local source_user=$1
    local target_user=$2
    
    local source_home="/home/$source_user"
    local target_home="/home/$target_user"
    
    # Git configuration
    if [ -f "$source_home/.gitconfig" ]; then
        cp "$source_home/.gitconfig" "$target_home/.gitconfig" 2>/dev/null
        chown "$target_user:$target_user" "$target_home/.gitconfig" 2>/dev/null
    fi
    
    # Git credentials (careful with this one)
    if [ -f "$source_home/.git-credentials" ]; then
        print_status warning "Git credentials file found. Copying without sensitive data."
        # Create a template without actual credentials
        echo "# Git credentials template - update with your actual credentials" > "$target_home/.git-credentials.template"
        chown "$target_user:$target_user" "$target_home/.git-credentials.template" 2>/dev/null
    fi
    
    # SSH config for Git
    if [ -f "/home/$source_user/.ssh/config" ]; then
        cp "/home/$source_user/.ssh/config" "/home/$target_user/.ssh/config" 2>/dev/null
        chown "$target_user:$target_user" "/home/$target_user/.ssh/config" 2>/dev/null
        chmod 600 "/home/$target_user/.ssh/config" 2>/dev/null
    fi
    
    print_status success "Git settings copied from $source_user to $target_user"
    log_message "Git settings copied from $source_user to $target_user"
}

# Copy all settings
copy_all_settings() {
    local source_user=$1
    local target_user=$2
    
    copy_ssh_settings "$source_user" "$target_user"
    copy_shell_settings "$source_user" "$target_user"
    copy_editor_settings "$source_user" "$target_user"
    copy_git_settings "$source_user" "$target_user"
    
    print_status success "All settings copied from $source_user to $target_user"
    log_message "All settings copied from $source_user to $target_user"
}

# User permissions setup function
setup_user_permissions() {
    local username=$1
    local permission_level=$2
    
    case $permission_level in
        admin)
            usermod -aG sudo "$username" 2>/dev/null
            print_status success "Admin privileges granted for $username"
            ;;
        user)
            # Remove from sudo group if present
            gpasswd -d "$username" sudo 2>/dev/null
            print_status success "Regular user privileges for $username"
            ;;
        restricted)
            # Disable password login, SSH keys only
            usermod -s /usr/sbin/nologin "$username" 2>/dev/null
            gpasswd -d "$username" sudo 2>/dev/null
            print_status success "Restricted privileges for $username"
            ;;
    esac
    
    log_message "User $username permissions changed to: $permission_level"
}

# Modify user permissions function
modify_user_permissions() {
    echo
    print_status info "=== MODIFY USER PERMISSIONS ==="
    
    read -p "Enter username: " username
    
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        print_status error "User $username does not exist"
        return 1
    fi
    
    # Check home directory
    if [ ! -d "/home/$username" ]; then
        print_status warning "User home directory not found"
    fi
    
    echo
    echo "Select permission level:"
    echo "1) Administrator (sudo privileges)"
    echo "2) Regular user"
    echo "3) Restricted access (SSH keys only)"
    echo "4) Lock user account"
    echo "5) Unlock user account"
    echo "0) Back to main menu"
    
    read -p "Select option [0-5]: " permission_choice
    
    case $permission_choice in
        1)
            setup_user_permissions "$username" "admin"
            ;;
        2)
            setup_user_permissions "$username" "user"
            ;;
        3)
            setup_user_permissions "$username" "restricted"
            ;;
        4)
            usermod -L "$username" 2>/dev/null
            print_status success "User $username locked"
            log_message "User $username locked"
            ;;
        5)
            usermod -U "$username" 2>/dev/null
            print_status success "User $username unlocked"
            log_message "User $username unlocked"
            ;;
        0)
            return
            ;;
        *)
            print_status error "Invalid selection"
            return 1
            ;;
    esac
}

# View user information function
view_user_info() {
    echo
    print_status info "=== USER INFORMATION ==="
    
    read -p "Enter username: " username
    
    if ! id "$username" &>/dev/null; then
        print_status error "User $username does not exist"
        return 1
    fi
    
    echo
    echo "User information for $username:"
    echo "-----------------------------------"
    id "$username"
    echo
    echo "User groups:"
    groups "$username"
    echo
    echo "Home directory:"
    ls -ld "/home/$username" 2>/dev/null || echo "Not found"
    echo
    echo "Account status:"
    passwd -S "$username" 2>/dev/null || echo "Unable to get status"
}

# Delete user function
delete_user() {
    echo
    print_status info "=== DELETE USER ==="
    
    read -p "Enter username to delete: " username
    
    if ! id "$username" &>/dev/null; then
        print_status error "User $username does not exist"
        return 1
    fi
    
    read -p "Delete home directory? (y/N): " delete_home
    
    echo
    print_status warning "WARNING: This action is irreversible!"
    read -p "Are you sure you want to delete user $username? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_status info "Deletion cancelled"
        return
    fi
    
    if [[ "$delete_home" == "y" || "$delete_home" == "Y" ]]; then
        userdel -r "$username" 2>/dev/null
        print_status success "User $username and home directory deleted"
        log_message "User $username deleted with home directory"
    else
        userdel "$username" 2>/dev/null
        print_status success "User $username deleted (home directory preserved)"
        log_message "User $username deleted"
    fi
}

# Main menu function
main_menu() {
    while true; do
        echo
        print_status info "=== UNIX USER MANAGER ==="
        echo
        echo "1) Create new user"
        echo "2) Modify user permissions"
        echo "3) Copy user settings"
        echo "4) View user information"
        echo "5) Delete user"
        echo "6) View operation log"
        echo "7) Exit"
        echo
        
        read -p "Select option [1-7]: " choice
        
        case $choice in
            1) create_user ;;
            2) modify_user_permissions ;;
            3) copy_user_settings ;;
            4) view_user_info ;;
            5) delete_user ;;
            6) 
                echo
                print_status info "=== OPERATION LOG ==="
                sudo cat "$LOG_FILE" 2>/dev/null || echo "Log file not found"
                ;;
            7)
                print_status info "Exiting..."
                exit 0
                ;;
            *)
                print_status error "Invalid selection"
                ;;
        esac
        
        read -p "Press Enter to continue..."
        clear
    done
}

# Initialization function
initialize() {
    check_sudo
    
    # Create log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 600 "$LOG_FILE"
    fi
    
    clear
    print_status info "User Manager started"
    log_message "=== User Manager session started ==="
}

# Main execution
initialize
main_menu
