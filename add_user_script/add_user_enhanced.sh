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
        echo "3) View user information"
        echo "4) Delete user"
        echo "5) View operation log"
        echo "6) Exit"
        echo
        
        read -p "Select option [1-6]: " choice
        
        case $choice in
            1) create_user ;;
            2) modify_user_permissions ;;
            3) view_user_info ;;
            4) delete_user ;;
            5) 
                echo
                print_status info "=== OPERATION LOG ==="
                sudo cat "$LOG_FILE" 2>/dev/null || echo "Log file not found"
                ;;
            6)
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
