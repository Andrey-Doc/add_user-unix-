🚀 Features

    User Creation: Create users from a text file with auto-generated secure passwords

    Group Management: Create groups from a text file

    Interactive Menu: User-friendly text-based interface using whiptail/dialog

    User Deletion: Safe user removal with confirmation and cleanup options

    Backup System: Automatic backup of system files before making changes

    Security: Secure password generation, permission management, and lock protection

    Logging: Comprehensive logging of all operations

    Configuration: Customizable through config file

📋 Requirements

    Unix/Linux system

    Root privileges

    Bash shell

    Required packages: openssl, whiptail (or dialog)

Install dependencies:

Ubuntu/Debian:
bash

sudo apt-get update
sudo apt-get install openssl whiptail

CentOS/RHEL:
bash

sudo yum install openssl newt

Fedora:
bash

sudo dnf install openssl newt

📁 File Structure

/
├── add_user.sh                  # Main script
├── users_list.txt               # User definitions
├── groups_list.txt              # Group definitions
├── /etc/user_manager.conf       # Configuration file
├── /var/log/user_management.log # Log file
└── /var/backups/user_management/ # Backup directory

⚙️ Configuration
Configuration File (/etc/user_manager.conf)
bash

# User Management Configuration
DEFAULT_UMASK=0022
PASSWORD_EXPIRE_DAYS=90
MIN_UID=1000
MAX_UID=60000
CREATE_HOME=yes
SKEL_DIR=/etc/skel
REMOVE_HOME_ON_DELETE=yes
REMOVE_MAIL_SPOOL=yes

Users File (users_list.txt)

Format: username:group1,group2,group3:comment
text

# Format: username:group1,group2,group3:comment
john:sudo,developers:John Doe
jane:developers:Jane Smith
bob:users:Bob Johnson
alice:sudo,admin:Alice Brown

Groups File (groups_list.txt)
text

# List of groups to create
developers
admin
users
sudo

🛠️ Installation

    Make it executable:

bash

chmod +x add_user_enhanced.sh

    Create configuration files:

bash

sudo mkdir -p /var/backups/user_management
sudo touch /var/log/user_management.log

    Create sample data files:

bash

# Create users_list.txt
cat > users_list.txt << EOF
john:sudo,developers:John Doe
jane:developers:Jane Smith
bob:users:Bob Johnson
EOF

# Create groups_list.txt
cat > groups_list.txt << EOF
developers
admin
users
sudo
EOF

📖 Usage
Interactive Mode (Recommended)
bash

sudo ./add_user.sh

This will launch the interactive menu with the following options:

    Create users and groups from files - Processes users_list.txt and groups_list.txt

    Delete users - Interactive user deletion menu

    Show all users - Display list of all regular users

    Show user information - Detailed info about specific user

    Exit - Quit the script

Automated Mode
bash

sudo ./add_user.sh --auto

Runs in non-interactive mode, automatically creating users and groups from files.
Custom File Locations
bash

sudo ./add_user.sh --users custom_users.txt --groups custom_groups.txt --config /path/to/config.conf

Help Command
bash

sudo ./add_user.sh --help

🎯 Step-by-Step Guide
Step 1: Prepare Your Files

    Edit users_list.txt with your users:

bash

nano users_list.txt

    Edit groups_list.txt with your groups:

bash

nano groups_list.txt

Step 2: Run the Script
bash

sudo ./add_user.sh

Step 3: Using the Menu

    Select option 1 to create users and groups

    The script will:

        Backup system files

        Create groups from groups_list.txt

        Create users from users_list.txt

        Generate secure passwords

        Set password expiration policies

        Save passwords to backup directory

    Passwords are stored in:

bash

/var/backups/user_management/passwords_YYYYMMDD.txt

Step 4: Managing Users

    View all users: Select option 3 from menu

    Get user info: Select option 4 and enter username

    Delete users: Select option 2 for interactive deletion menu

🔒 Security Features

    Automatic backups of /etc/passwd, /etc/group, /etc/shadow, /etc/gshadow

    Secure password generation using OpenSSL (16 characters, mixed character sets)

    File permission enforcement for sensitive files

    Password expiration policies enforced by default

    Lock protection to prevent concurrent execution

    Input validation for all user operations

    Secure temporary file handling

⚠️ Safety Features

    Confirmation prompts for destructive operations

    Dry-run mode available for testing

    Comprehensive error checking and handling

    Rollback capability from backups in case of errors

    User existence verification before operations

🔧 Advanced Usage
Custom Configuration

Create a custom configuration file:
bash

sudo nano /etc/user_manager_custom.conf

Then run with custom config:
bash

sudo ./add_user.sh --config /etc/user_manager_custom.conf

Logging and Debugging

Enable verbose logging:
bash

sudo ./add_user.sh --verbose

View logs:
bash

tail -f /var/log/user_management.log

Password Policy Customization

Modify the password generation function in the script to meet your organization's requirements:
bash

# In the script, look for the generate_password function
generate_password() {
    # Customize this function for your needs
    openssl rand -base64 16 | tr -d '/+=' | cut -c1-16
}

🐛 Troubleshooting
Common Issues

    Permission denied errors

        Ensure script is run with sudo

        Verify backup directory permissions

    Whiptail/dialog not found

        Install required packages as shown in Requirements section

    User/group already exists

        Script will skip existing users/groups by default

Debug Mode

Run with debug output:
bash

sudo ./add_user.sh --debug
