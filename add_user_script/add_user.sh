#!/bin/bash

# Скрипт для добавления нового пользователя в Linux
# Автор: Assistant
# Версия: 1.0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода цветного текста
print_color() {
    local color=$1
    local text=$2
    echo -e "${color}${text}${NC}"
}

# Функция для проверки root прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color $RED "Ошибка: Этот скрипт должен быть запущен с правами root (sudo)"
        exit 1
    fi
}

# Функция для проверки существования пользователя
user_exists() {
    local username=$1
    id "$username" &>/dev/null
    return $?
}

# Функция для создания пользователя
create_user() {
    local username=$1
    local full_name=$2
    local shell=$3
    
    print_color $BLUE "Создание пользователя: $username"
    
    # Создаем пользователя
    if useradd -m -s "$shell" -c "$full_name" "$username"; then
        print_color $GREEN "Пользователь $username успешно создан"
        return 0
    else
        print_color $RED "Ошибка при создании пользователя $username"
        return 1
    fi
}

# Функция для установки пароля
set_password() {
    local username=$1
    print_color $YELLOW "Установка пароля для пользователя $username"
    passwd "$username"
}

# Функция для добавления в группы
add_to_groups() {
    local username=$1
    local groups=("$@")
    
    print_color $BLUE "Добавление пользователя в группы..."
    
    for group in "${groups[@]}"; do
        if [[ -n "$group" ]]; then
            if usermod -a -G "$group" "$username"; then
                print_color $GREEN "Пользователь добавлен в группу: $group"
            else
                print_color $RED "Ошибка при добавлении в группу: $group"
            fi
        fi
    done
}

# Функция для настройки sudo прав
configure_sudo() {
    local username=$1
    local sudo_level=$2
    
    print_color $BLUE "Настройка sudo прав для пользователя $username"
    
    case $sudo_level in
        1) # Без sudo прав
            print_color $YELLOW "Пользователь не получит sudo прав"
            ;;
        2) # Ограниченные sudo права
            echo "$username ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg" >> /etc/sudoers.d/$username
            print_color $GREEN "Добавлены ограниченные sudo права"
            ;;
        3) # Полные sudo права
            echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$username
            print_color $GREEN "Добавлены полные sudo права"
            ;;
    esac
}

# Функция для добавления SSH ключей
add_ssh_keys() {
    local username=$1
    
    print_color $BLUE "Настройка SSH ключей для пользователя $username"
    
    # Создаем директорию .ssh если её нет
    local ssh_dir="/home/$username/.ssh"
    mkdir -p "$ssh_dir"
    chown "$username:$username" "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Создаем файл authorized_keys
    local auth_keys_file="$ssh_dir/authorized_keys"
    touch "$auth_keys_file"
    chown "$username:$username" "$auth_keys_file"
    chmod 600 "$auth_keys_file"
    
    print_color $YELLOW "Выберите способ добавления SSH ключей:"
    echo "1) Ввести ключ вручную"
    echo "2) Скопировать ключ из файла"
    echo "3) Пропустить"
    read -p "Выберите опцию (1-3): " ssh_choice
    
    case $ssh_choice in
        1)
            print_color $YELLOW "Введите SSH публичный ключ (завершите ввод нажатием Ctrl+D):"
            cat >> "$auth_keys_file"
            print_color $GREEN "SSH ключ добавлен"
            ;;
        2)
            read -p "Введите путь к файлу с SSH ключом: " key_file
            if [[ -f "$key_file" ]]; then
                cat "$key_file" >> "$auth_keys_file"
                print_color $GREEN "SSH ключ скопирован из файла"
            else
                print_color $RED "Файл не найден: $key_file"
            fi
            ;;
        3)
            print_color $YELLOW "Добавление SSH ключей пропущено"
            ;;
        *)
            print_color $RED "Неверный выбор"
            ;;
    esac
}

# Функция для отображения меню
show_menu() {
    clear
    print_color $BLUE "=== Скрипт добавления пользователя в Linux ==="
    echo
    print_color $YELLOW "Выберите действие:"
    echo "1) Добавить нового пользователя"
    echo "2) Выход"
    echo
}

# Функция для получения информации о пользователе
get_user_info() {
    echo
    print_color $BLUE "=== Ввод информации о пользователе ==="
    echo
    
    # Имя пользователя
    while true; do
        read -p "Введите имя пользователя: " username
        if [[ -z "$username" ]]; then
            print_color $RED "Имя пользователя не может быть пустым"
            continue
        fi
        if user_exists "$username"; then
            print_color $RED "Пользователь $username уже существует"
            continue
        fi
        break
    done
    
    # Полное имя
    read -p "Введите полное имя пользователя: " full_name
    
    # Shell
    print_color $YELLOW "Выберите shell для пользователя:"
    echo "1) /bin/bash (рекомендуется)"
    echo "2) /bin/zsh"
    echo "3) /bin/sh"
    echo "4) /sbin/nologin (без доступа к shell)"
    read -p "Выберите shell (1-4): " shell_choice
    
    case $shell_choice in
        1) shell="/bin/bash" ;;
        2) shell="/bin/zsh" ;;
        3) shell="/bin/sh" ;;
        4) shell="/sbin/nologin" ;;
        *) shell="/bin/bash" ;;
    esac
    
    # Группы
    print_color $YELLOW "Доступные группы:"
    echo "1) sudo"
    echo "2) docker"
    echo "3) www-data"
    echo "4) video"
    echo "5) audio"
    echo "6) disk"
    echo "7) users (по умолчанию)"
    echo "8) Другая группа"
    echo "9) Не добавлять в дополнительные группы"
    
    read -p "Выберите группы (через запятую, например: 1,2,3): " group_choices
    
    groups=()
    IFS=',' read -ra GROUP_CHOICES <<< "$group_choices"
    
    for choice in "${GROUP_CHOICES[@]}"; do
        case $choice in
            1) groups+=("sudo") ;;
            2) groups+=("docker") ;;
            3) groups+=("www-data") ;;
            4) groups+=("video") ;;
            5) groups+=("audio") ;;
            6) groups+=("disk") ;;
            7) groups+=("users") ;;
            8)
                read -p "Введите название группы: " custom_group
                if getent group "$custom_group" >/dev/null 2>&1; then
                    groups+=("$custom_group")
                else
                    print_color $RED "Группа $custom_group не существует"
                fi
                ;;
        esac
    done
    
    # Sudo права
    print_color $YELLOW "Настройка sudo прав:"
    echo "1) Без sudo прав"
    echo "2) Ограниченные sudo права (только apt, apt-get, dpkg)"
    echo "3) Полные sudo права"
    read -p "Выберите уровень sudo прав (1-3): " sudo_level
    
    # SSH ключи
    print_color $YELLOW "Добавить SSH ключи для пользователя? (y/n): "
    read -p "" add_ssh
    
    # Подтверждение
    echo
    print_color $BLUE "=== Сводка настроек ==="
    echo "Имя пользователя: $username"
    echo "Полное имя: $full_name"
    echo "Shell: $shell"
    echo "Группы: ${groups[*]}"
    echo "Sudo права: $sudo_level"
    echo "SSH ключи: $add_ssh"
    echo
    
    read -p "Продолжить создание пользователя? (y/n): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Создание пользователя
        if create_user "$username" "$full_name" "$shell"; then
            # Установка пароля
            set_password "$username"
            
            # Добавление в группы
            if [[ ${#groups[@]} -gt 0 ]]; then
                add_to_groups "$username" "${groups[@]}"
            fi
            
            # Настройка sudo
            configure_sudo "$username" "$sudo_level"
            
            # Добавление SSH ключей
            if [[ "$add_ssh" =~ ^[Yy]$ ]]; then
                add_ssh_keys "$username"
            fi
            
            echo
            print_color $GREEN "=== Пользователь $username успешно создан! ==="
            echo "Домашняя директория: /home/$username"
            echo "Shell: $shell"
            echo "Группы: $(groups "$username" | cut -d: -f2)"
            echo
        fi
    else
        print_color $YELLOW "Создание пользователя отменено"
    fi
}

# Основная функция
main() {
    check_root
    
    while true; do
        show_menu
        read -p "Выберите опцию (1-2): " choice
        
        case $choice in
            1)
                get_user_info
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            2)
                print_color $GREEN "До свидания!"
                exit 0
                ;;
            *)
                print_color $RED "Неверный выбор"
                sleep 2
                ;;
        esac
    done
}

# Запуск основной функции
main "$@" 