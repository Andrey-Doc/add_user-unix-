# Enhanced Linux User Management Script

An interactive bash script for creating and managing users in Linux with advanced features for permissions, groups, SSH keys, and system administration.

## 🚀 Features

### Core User Management
- ✅ Create new users with home directories
- ✅ Choose shell (bash, zsh, sh, nologin)
- ✅ Add users to groups (sudo, docker, www-data, video, audio, disk, users)
- ✅ Configure sudo permissions (no rights, limited, full, with password)
- ✅ Add SSH keys (manual input, file copy, key generation)
- ✅ Color-coded output for better UX
- ✅ User existence validation
- ✅ Interactive menu system

### Advanced Features (Enhanced Version)
- 🔄 **Logging System** - All actions logged to `/var/log/user_creation.log`
- 💾 **Backup System** - Automatic user backup creation
- 🗑️ **User Deletion** - Safe user removal with backup options
- 📊 **User Information** - Detailed user information display
- 📤 **User Export** - Export users to CSV format
- 📥 **Batch Import** - Create users from CSV file
- 🔐 **Auto Password** - Automatic password setting
- ⚙️ **System Limits** - Configure user resource limits
- 🏗️ **Environment Setup** - Create useful directories and configs
- 🔍 **System Validation** - Check system requirements
- 🛡️ **Enhanced Security** - Better input validation and safety checks
- 📋 **Settings Copy** - Copy user settings from one user to another

## Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/your-repo/add_user_script/main/add_user_enhanced.sh
```

2. Make the script executable:
```bash
chmod +x add_user_enhanced.sh
```

## Usage

### Basic Usage

```bash
sudo ./add_user_enhanced.sh
```

**Important:** The script must be run with root privileges (sudo).

### Enhanced Menu Options

The enhanced script provides 8 main options:

1. **Add New User** - Interactive user creation
2. **Create Users from File** - Batch user creation from CSV
3. **Export Users** - Export existing users to CSV
4. **Delete User** - Remove user with backup option
5. **Show User Information** - Display detailed user info
6. **Create User Backup** - Backup specific user
7. **Copy User Settings** - Copy settings from one user to another
8. **Exit** - Quit the script

## Step-by-Step Guide

### 1. Adding a New User

1. **Launch the script** with sudo privileges
2. **Select "1"** to add a new user
3. **Enter username** (validated for existence)
4. **Enter full name** of the user
5. **Choose UID** (optional, auto-assigned if empty)
6. **Select shell**:
   - `/bin/bash` (recommended)
   - `/bin/zsh`
   - `/bin/sh`
   - `/sbin/nologin` (no shell access)
7. **Choose groups** (multiple selection via comma):
   - `sudo` - administrator rights
   - `docker` - Docker access
   - `www-data` - web server access
   - `video` - video device access
   - `audio` - audio device access
   - `disk` - disk access
   - `users` - standard user group
   - Custom group (manual input)
8. **Configure sudo rights**:
   - No sudo rights
   - Limited (apt, apt-get, dpkg, systemctl)
   - Full sudo rights (no password)
   - Sudo with password prompt
9. **Set system limits** (optional)
10. **Add SSH keys** (optional):
    - Manual key input
    - Copy from file
    - Generate new key
    - Skip
11. **Set password**:
    - Automatic password setting
    - Interactive password setting
12. **Confirm user creation**

### 2. Batch User Creation

Create a CSV file with user data:
```csv
username,full_name,shell,groups,sudo_level,ssh_keys
john,John Doe,/bin/bash,sudo,docker,3,yes
jane,Jane Smith,/bin/zsh,users,1,no
admin,Admin User,/bin/bash,sudo,3,yes
```

Then use option 2 to import users from the file.

### 3. User Export

Use option 3 to export all users to a CSV file with their configurations.

### 4. User Deletion

Use option 4 to safely delete users with backup creation option.

### 5. Copy User Settings

Use option 7 to copy settings from one user to another. This function allows:

**What gets copied:**
- SSH keys and configuration (`.ssh/`)
- Shell settings (`.bashrc`, `.zshrc`, `.profile`)
- Application settings (`.config/`, `.mozilla`, `.thunderbird`)
- Terminal settings (`.inputrc`, `.screenrc`, `.tmux.conf`)
- Desktop folders (Desktop, Documents, Downloads, etc.)
- Sudo rights and system limits
- Editor settings (`.vimrc`, `.vim`)

**Copy options:**
1. **All settings** - Complete copy of all settings
2. **SSH only** - Copy SSH keys and configuration
3. **Shell only** - Copy shell settings
4. **Applications only** - Copy application settings
5. **System only** - Copy sudo rights and limits
6. **Selective** - Choose specific files to copy

**Security:**
- Automatic backup creation before copying
- Proper permission setting
- User existence validation
- Comprehensive logging

## Examples

### Creating a Regular User
```bash
sudo ./add_user_enhanced.sh
# Follow the menu instructions
```

### Creating an Administrator User
1. Launch the script
2. Choose groups: `1,7` (sudo + users)
3. Choose sudo rights: `3` (full)
4. Add SSH keys if needed

### Creating a Web Developer User
1. Launch the script
2. Choose groups: `2,3` (docker + www-data)
3. Choose sudo rights: `2` (limited)
4. Add SSH keys

### Creating a System User (No Shell)
1. Launch the script
2. Choose shell: `4` (nologin)
3. Choose groups: `3` (www-data)
4. No sudo rights
5. No SSH keys

## File Structure

After user creation, the following files are created:
- Home directory: `/home/username`
- SSH directory: `/home/username/.ssh/` (if keys added)
- Authorized keys file: `/home/username/.ssh/authorized_keys`
- Sudo configuration: `/etc/sudoers.d/username`
- User limits: `/etc/security/limits.d/username.conf`
- Log file: `/var/log/user_creation.log`
- Backup directory: `/root/user_backups/`

## Security Features

- ✅ Root privilege verification before execution
- ✅ User existence validation before creation
- ✅ SSH keys installed with correct permissions (700 for directory, 600 for file)
- ✅ Sudo rights configured through separate files in `/etc/sudoers.d/`
- ✅ Input validation and sanitization
- ✅ Secure user deletion with backup options
- ✅ System requirements validation
- ✅ Comprehensive logging for audit trail

## Logging System

The enhanced script includes a comprehensive logging system:

- **Log file**: `/var/log/user_creation.log`
- **Log levels**: INFO, WARNING, ERROR
- **Timestamps**: All entries include date and time
- **Actions logged**: User creation, deletion, modifications, errors
- **Security**: Log file has restricted permissions (600)

## Backup System

- **Automatic backups**: Created before user deletion
- **Backup location**: `/root/user_backups/`
- **Backup format**: Compressed tar archives
- **Naming convention**: `username_YYYYMMDD_HHMMSS.tar.gz`
- **Contents**: Complete home directory

## System Requirements

- Linux system
- Root privileges (sudo)
- Bash shell
- Standard Linux utilities (useradd, usermod, passwd, etc.)
- tar (for backups)
- chpasswd (for automatic password setting)

## Troubleshooting

### "Permission denied" Error
```bash
sudo ./add_user_enhanced.sh
```

### User Already Exists
The script automatically checks for existing users and prompts for a different name.

### SSH Issues
Check file permissions:
```bash
ls -la /home/username/.ssh/
```

### Sudo Issues
Check configuration:
```bash
sudo visudo -f /etc/sudoers.d/username
```

### Log File Issues
Check log file permissions:
```bash
sudo chmod 600 /var/log/user_creation.log
```

### Backup Issues
Check backup directory:
```bash
ls -la /root/user_backups/
```

## Advanced Features Explained

### 1. Logging System
- All script actions are logged with timestamps
- Different log levels (INFO, WARNING, ERROR)
- Log file location: `/var/log/user_creation.log`
- Useful for audit trails and debugging

### 2. Backup System
- Automatic backup creation before user deletion
- Compressed tar archives of home directories
- Backup naming includes timestamp
- Safe user removal with data preservation

### 3. Batch Operations
- Create multiple users from CSV file
- Export existing users to CSV format
- Useful for system administration and migration

### 4. Enhanced Security
- Input validation for all user inputs
- System requirements checking
- Secure file permissions
- Comprehensive error handling

### 5. User Information Display
- Detailed user information including:
  - UID/GID
  - Home directory
  - Shell
  - Group memberships
  - Sudo configuration
  - SSH key count
  - Last login information

### 6. System Limits Configuration
- Configures user resource limits
- File: `/etc/security/limits.d/username.conf`
- Sets file descriptor limits
- Sets process limits

### 7. Environment Setup
- Creates useful directories (bin, src, downloads, documents)
- Copies default configuration files
- Sets proper ownership and permissions

### 8. User Settings Copy
- Complete copy of all settings from one user to another
- Selective copying of specific settings
- SSH keys and configuration copying
- Shell and application settings copying
- Sudo rights and system limits copying
- Automatic backup creation
- Secure permission setting

## CSV File Format for Batch Import

```csv
username,full_name,shell,groups,sudo_level,ssh_keys
john,John Doe,/bin/bash,sudo,docker,3,yes
jane,Jane Smith,/bin/zsh,users,1,no
admin,Admin User,/bin/bash,sudo,3,yes
```

**Fields:**
- `username`: User login name
- `full_name`: User's full name
- `shell`: Login shell path
- `groups`: Comma-separated group list
- `sudo_level`: 1=none, 2=limited, 3=full, 4=with password
- `ssh_keys`: yes/no for SSH key setup

## Version History

### Version 2.0 (Enhanced)
- Added comprehensive logging system
- Added backup functionality
- Added user deletion with safety checks
- Added batch user creation from CSV
- Added user export to CSV
- Added user information display
- Added system limits configuration
- Added environment setup
- Added automatic password setting
- Added system requirements validation
- Added user settings copy functionality
- Enhanced security features
- Improved error handling

### Version 1.0 (Basic)
- Basic user creation
- Group management
- SSH key configuration
- Sudo rights configuration
- Interactive menu

## License

MIT License

## Author

Assistant - 2024

## Contributing

Feel free to submit issues and enhancement requests! 