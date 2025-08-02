#!/bin/bash

# Улучшенный скрипт для добавления нового пользователя в Linux
# Автор: Assistant
# Версия: 2.0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Глобальные переменные
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/user_creation.log"
BACKUP_DIR="/root/user_backups"

# Функция для логирования
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo -e "${CYAN}[$timestamp]${NC} [$level] $message"
}

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

# Функция для создания резервной копии
create_backup() {
    local username=$1
    local backup_file="$BACKUP_DIR/${username}_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    if tar -czf "$backup_file" -C /home "$username" 2>/dev/null; then
        log_message "INFO" "Создана резервная копия пользователя $username: $backup_file"
        print_color $GREEN "Резервная копия создана: $backup_file"
    else
        log_message "WARNING" "Не удалось создать резервную копию для $username"
        print_color $YELLOW "Предупреждение: Не удалось создать резервную копию"
    fi
}

# Функция для проверки существования пользователя
user_exists() {
    local username=$1
    id "$username" &>/dev/null
    return $?
}

# Функция для проверки системных требований
check_system_requirements() {
    local missing_packages=()
    
    # Проверяем необходимые команды
    local required_commands=("useradd" "usermod" "passwd" "groupadd" "chown" "chmod")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_packages+=("$cmd")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_color $RED "Ошибка: Отсутствуют необходимые пакеты: ${missing_packages[*]}"
        log_message "ERROR" "Отсутствуют пакеты: ${missing_packages[*]}"
        exit 1
    fi
    
    log_message "INFO" "Системные требования проверены"
}

# Функция для создания пользователя
create_user() {
    local username=$1
    local full_name=$2
    local shell=$3
    local uid=$4
    
    print_color $BLUE "Создание пользователя: $username"
    log_message "INFO" "Начинаем создание пользователя: $username"
    
    # Создаем пользователя с опциональным UID
    local useradd_cmd="useradd -m -s \"$shell\" -c \"$full_name\""
    if [[ -n "$uid" ]]; then
        useradd_cmd="$useradd_cmd -u $uid"
    fi
    useradd_cmd="$useradd_cmd \"$username\""
    
    if eval "$useradd_cmd"; then
        print_color $GREEN "Пользователь $username успешно создан"
        log_message "INFO" "Пользователь $username создан успешно"
        return 0
    else
        print_color $RED "Ошибка при создании пользователя $username"
        log_message "ERROR" "Ошибка при создании пользователя $username"
        return 1
    fi
}

# Функция для установки пароля
set_password() {
    local username=$1
    local password=$2
    
    print_color $YELLOW "Установка пароля для пользователя $username"
    
    if [[ -n "$password" ]]; then
        # Устанавливаем пароль автоматически
        echo "$username:$password" | chpasswd
        print_color $GREEN "Пароль установлен автоматически"
        log_message "INFO" "Пароль для $username установлен автоматически"
    else
        # Интерактивная установка пароля
        passwd "$username"
        log_message "INFO" "Пароль для $username установлен интерактивно"
    fi
}

# Функция для создания групп
create_groups() {
    local groups=("$@")
    
    print_color $BLUE "Создание групп..."
    
    for group in "${groups[@]}"; do
        if [[ -n "$group" ]]; then
            if ! getent group "$group" >/dev/null 2>&1; then
                if groupadd "$group"; then
                    print_color $GREEN "Группа $group создана"
                    log_message "INFO" "Группа $group создана"
                else
                    print_color $RED "Ошибка при создании группы $group"
                    log_message "ERROR" "Ошибка при создании группы $group"
                fi
            else
                print_color $YELLOW "Группа $group уже существует"
            fi
        fi
    done
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
                log_message "INFO" "Пользователь $username добавлен в группу $group"
            else
                print_color $RED "Ошибка при добавлении в группу: $group"
                log_message "ERROR" "Ошибка при добавлении $username в группу $group"
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
            log_message "INFO" "Пользователь $username не получил sudo прав"
            ;;
        2) # Ограниченные sudo права
            echo "$username ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/systemctl" >> /etc/sudoers.d/$username
            print_color $GREEN "Добавлены ограниченные sudo права"
            log_message "INFO" "Добавлены ограниченные sudo права для $username"
            ;;
        3) # Полные sudo права
            echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$username
            print_color $GREEN "Добавлены полные sudo права"
            log_message "INFO" "Добавлены полные sudo права для $username"
            ;;
        4) # Sudo с паролем
            echo "$username ALL=(ALL) ALL" >> /etc/sudoers.d/$username
            print_color $GREEN "Добавлены sudo права с запросом пароля"
            log_message "INFO" "Добавлены sudo права с паролем для $username"
            ;;
    esac
}

# Функция для настройки ограничений
configure_limits() {
    local username=$1
    local limits_file="/etc/security/limits.d/$username.conf"
    
    print_color $BLUE "Настройка ограничений для пользователя $username"
    
    cat > "$limits_file" << EOF
# Ограничения для пользователя $username
$username soft nofile 65536
$username hard nofile 65536
$username soft nproc 32768
$username hard nproc 32768
EOF
    
    print_color $GREEN "Ограничения настроены"
    log_message "INFO" "Ограничения настроены для $username"
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
    echo "3) Сгенерировать новый ключ"
    echo "4) Пропустить"
    read -p "Выберите опцию (1-4): " ssh_choice
    
    case $ssh_choice in
        1)
            print_color $YELLOW "Введите SSH публичный ключ (завершите ввод нажатием Ctrl+D):"
            cat >> "$auth_keys_file"
            print_color $GREEN "SSH ключ добавлен"
            log_message "INFO" "SSH ключ добавлен для $username"
            ;;
        2)
            read -p "Введите путь к файлу с SSH ключом: " key_file
            if [[ -f "$key_file" ]]; then
                cat "$key_file" >> "$auth_keys_file"
                print_color $GREEN "SSH ключ скопирован из файла"
                log_message "INFO" "SSH ключ скопирован из файла для $username"
            else
                print_color $RED "Файл не найден: $key_file"
                log_message "ERROR" "Файл SSH ключа не найден: $key_file"
            fi
            ;;
        3)
            print_color $YELLOW "Генерация нового SSH ключа..."
            if su - "$username" -c "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"; then
                print_color $GREEN "SSH ключ сгенерирован"
                log_message "INFO" "SSH ключ сгенерирован для $username"
            else
                print_color $RED "Ошибка при генерации SSH ключа"
                log_message "ERROR" "Ошибка при генерации SSH ключа для $username"
            fi
            ;;
        4)
            print_color $YELLOW "Добавление SSH ключей пропущено"
            log_message "INFO" "Добавление SSH ключей пропущено для $username"
            ;;
        *)
            print_color $RED "Неверный выбор"
            ;;
    esac
}

# Функция для настройки окружения
setup_environment() {
    local username=$1
    
    print_color $BLUE "Настройка окружения для пользователя $username"
    
    # Копируем базовые конфигурационные файлы
    local home_dir="/home/$username"
    
    # Bash профиль
    if [[ ! -f "$home_dir/.bashrc" ]]; then
        cp /etc/skel/.bashrc "$home_dir/"
        chown "$username:$username" "$home_dir/.bashrc"
    fi
    
    # Bash профиль
    if [[ ! -f "$home_dir/.profile" ]]; then
        cp /etc/skel/.profile "$home_dir/"
        chown "$username:$username" "$home_dir/.profile"
    fi
    
    # Создаем полезные директории
    local dirs=("bin" "src" "downloads" "documents")
    for dir in "${dirs[@]}"; do
        mkdir -p "$home_dir/$dir"
        chown "$username:$username" "$home_dir/$dir"
    done
    
    print_color $GREEN "Окружение настроено"
    log_message "INFO" "Окружение настроено для $username"
}

# Функция для создания пользователя из файла
create_user_from_file() {
    local file_path=$1
    
    if [[ ! -f "$file_path" ]]; then
        print_color $RED "Файл не найден: $file_path"
        return 1
    fi
    
    print_color $BLUE "Создание пользователей из файла: $file_path"
    
    while IFS=',' read -r username full_name shell groups sudo_level ssh_keys; do
        # Пропускаем заголовок и пустые строки
        [[ "$username" =~ ^#.*$ ]] && continue
        [[ -z "$username" ]] && continue
        
        print_color $YELLOW "Обработка пользователя: $username"
        
        if user_exists "$username"; then
            print_color $RED "Пользователь $username уже существует, пропускаем"
            continue
        fi
        
        # Создаем пользователя
        if create_user "$username" "$full_name" "$shell"; then
            # Добавляем в группы
            IFS=',' read -ra GROUP_ARRAY <<< "$groups"
            add_to_groups "$username" "${GROUP_ARRAY[@]}"
            
            # Настраиваем sudo
            configure_sudo "$username" "$sudo_level"
            
            # Добавляем SSH ключи если указано
            if [[ "$ssh_keys" == "yes" ]]; then
                add_ssh_keys "$username"
            fi
            
            print_color $GREEN "Пользователь $username создан успешно"
        fi
        
    done < "$file_path"
}

# Функция для экспорта пользователей
export_users() {
    local export_file="$SCRIPT_DIR/users_export_$(date +%Y%m%d_%H%M%S).csv"
    
    print_color $BLUE "Экспорт пользователей в файл: $export_file"
    
    echo "username,full_name,shell,groups,sudo_level" > "$export_file"
    
    while IFS=: read -r username x uid gid info home shell; do
        if [[ "$uid" -ge 1000 ]] && [[ "$uid" -le 65000 ]]; then
            local groups=$(groups "$username" | cut -d: -f2 | tr ' ' ',')
            local sudo_level="none"
            
            if [[ -f "/etc/sudoers.d/$username" ]]; then
                if grep -q "NOPASSWD: ALL" "/etc/sudoers.d/$username"; then
                    sudo_level="full"
                elif grep -q "NOPASSWD:" "/etc/sudoers.d/$username"; then
                    sudo_level="limited"
                else
                    sudo_level="with_password"
                fi
            fi
            
            echo "$username,$info,$shell,$groups,$sudo_level" >> "$export_file"
        fi
    done < /etc/passwd
    
    print_color $GREEN "Экспорт завершен: $export_file"
    log_message "INFO" "Экспорт пользователей завершен: $export_file"
}

# Функция для удаления пользователя
delete_user() {
    local username=$1
    local backup_choice=$2
    
    if ! user_exists "$username"; then
        print_color $RED "Пользователь $username не существует"
        return 1
    fi
    
    print_color $RED "ВНИМАНИЕ: Вы собираетесь удалить пользователя $username"
    
    if [[ "$backup_choice" != "yes" ]]; then
        read -p "Создать резервную копию перед удалением? (y/n): " backup_choice
    fi
    
    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        create_backup "$username"
    fi
    
    read -p "Удалить домашнюю директорию? (y/n): " delete_home
    read -p "Удалить пользователя? (y/n): " confirm_delete
    
    if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
        local userdel_cmd="userdel"
        if [[ "$delete_home" =~ ^[Yy]$ ]]; then
            userdel_cmd="userdel -r"
        fi
        
        if $userdel_cmd "$username"; then
            # Удаляем sudo конфигурацию
            rm -f "/etc/sudoers.d/$username"
            
            print_color $GREEN "Пользователь $username удален"
            log_message "INFO" "Пользователь $username удален"
        else
            print_color $RED "Ошибка при удалении пользователя $username"
            log_message "ERROR" "Ошибка при удалении пользователя $username"
        fi
    else
        print_color $YELLOW "Удаление отменено"
    fi
}

# Функция для отображения информации о пользователе
show_user_info() {
    local username=$1
    
    if ! user_exists "$username"; then
        print_color $RED "Пользователь $username не существует"
        return 1
    fi
    
    print_color $BLUE "=== Информация о пользователе $username ==="
    
    # Основная информация
    local user_info=$(getent passwd "$username")
    local uid=$(echo "$user_info" | cut -d: -f3)
    local gid=$(echo "$user_info" | cut -d: -f4)
    local home=$(echo "$user_info" | cut -d: -f6)
    local shell=$(echo "$user_info" | cut -d: -f7)
    
    echo "UID: $uid"
    echo "GID: $gid"
    echo "Домашняя директория: $home"
    echo "Shell: $shell"
    
    # Группы
    echo "Группы: $(groups "$username" | cut -d: -f2)"
    
    # Sudo права
    if [[ -f "/etc/sudoers.d/$username" ]]; then
        echo "Sudo права: Да"
        echo "Sudo конфигурация:"
        cat "/etc/sudoers.d/$username"
    else
        echo "Sudo права: Нет"
    fi
    
    # SSH ключи
    local ssh_dir="$home/.ssh"
    if [[ -d "$ssh_dir" ]]; then
        echo "SSH директория: $ssh_dir"
        if [[ -f "$ssh_dir/authorized_keys" ]]; then
            local key_count=$(wc -l < "$ssh_dir/authorized_keys")
            echo "Количество SSH ключей: $key_count"
        fi
    fi
    
    # Последний вход
    local last_login=$(lastlog -u "$username" 2>/dev/null | tail -n +2)
    if [[ -n "$last_login" ]]; then
        echo "Последний вход: $last_login"
    else
        echo "Последний вход: Никогда"
    fi
}

# Функция для отображения меню
show_menu() {
    clear
    print_color $BLUE "=== Улучшенный скрипт управления пользователями Linux ==="
    echo
    print_color $YELLOW "Выберите действие:"
    echo "1) Добавить нового пользователя"
    echo "2) Создать пользователей из файла"
    echo "3) Экспортировать пользователей"
    echo "4) Удалить пользователя"
    echo "5) Показать информацию о пользователе"
    echo "6) Создать резервную копию пользователя"
    echo "7) Выход"
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
    
    # UID (опционально)
    read -p "Введите UID (оставьте пустым для автоматического): " uid
    
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
    echo "2) Ограниченные sudo права (apt, apt-get, dpkg, systemctl)"
    echo "3) Полные sudo права (без пароля)"
    echo "4) Sudo права с запросом пароля"
    read -p "Выберите уровень sudo прав (1-4): " sudo_level
    
    # Ограничения
    read -p "Настроить ограничения для пользователя? (y/n): " set_limits
    
    # SSH ключи
    print_color $YELLOW "Добавить SSH ключи для пользователя? (y/n): "
    read -p "" add_ssh
    
    # Автоматический пароль
    read -p "Установить пароль автоматически? (y/n): " auto_password
    password=""
    if [[ "$auto_password" =~ ^[Yy]$ ]]; then
        read -s -p "Введите пароль: " password
        echo
        read -s -p "Подтвердите пароль: " password_confirm
        echo
        if [[ "$password" != "$password_confirm" ]]; then
            print_color $RED "Пароли не совпадают, будет использован интерактивный режим"
            password=""
        fi
    fi
    
    # Подтверждение
    echo
    print_color $BLUE "=== Сводка настроек ==="
    echo "Имя пользователя: $username"
    echo "Полное имя: $full_name"
    echo "UID: ${uid:-автоматический}"
    echo "Shell: $shell"
    echo "Группы: ${groups[*]}"
    echo "Sudo права: $sudo_level"
    echo "Ограничения: $set_limits"
    echo "SSH ключи: $add_ssh"
    echo "Автоматический пароль: $auto_password"
    echo
    
    read -p "Продолжить создание пользователя? (y/n): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Создание групп если нужно
        create_groups "${groups[@]}"
        
        # Создание пользователя
        if create_user "$username" "$full_name" "$shell" "$uid"; then
            # Установка пароля
            set_password "$username" "$password"
            
            # Добавление в группы
            if [[ ${#groups[@]} -gt 0 ]]; then
                add_to_groups "$username" "${groups[@]}"
            fi
            
            # Настройка sudo
            configure_sudo "$username" "$sudo_level"
            
            # Настройка ограничений
            if [[ "$set_limits" =~ ^[Yy]$ ]]; then
                configure_limits "$username"
            fi
            
            # Добавление SSH ключей
            if [[ "$add_ssh" =~ ^[Yy]$ ]]; then
                add_ssh_keys "$username"
            fi
            
            # Настройка окружения
            setup_environment "$username"
            
            echo
            print_color $GREEN "=== Пользователь $username успешно создан! ==="
            echo "Домашняя директория: /home/$username"
            echo "Shell: $shell"
            echo "Группы: $(groups "$username" | cut -d: -f2)"
            echo
            
            # Показываем информацию о созданном пользователе
            show_user_info "$username"
        fi
    else
        print_color $YELLOW "Создание пользователя отменено"
    fi
}

# Основная функция
main() {
    check_root
    check_system_requirements
    
    # Создаем лог файл если его нет
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    
    log_message "INFO" "Скрипт запущен"
    
    while true; do
        show_menu
        read -p "Выберите опцию (1-7): " choice
        
        case $choice in
            1)
                get_user_info
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            2)
                read -p "Введите путь к файлу с пользователями: " file_path
                create_user_from_file "$file_path"
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            3)
                export_users
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            4)
                read -p "Введите имя пользователя для удаления: " username
                delete_user "$username"
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            5)
                read -p "Введите имя пользователя: " username
                show_user_info "$username"
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            6)
                read -p "Введите имя пользователя для резервного копирования: " username
                if user_exists "$username"; then
                    create_backup "$username"
                else
                    print_color $RED "Пользователь $username не существует"
                fi
                echo
                read -p "Нажмите Enter для продолжения..."
                ;;
            7)
                print_color $GREEN "До свидания!"
                log_message "INFO" "Скрипт завершен"
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