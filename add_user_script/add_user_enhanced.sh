#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Лог файл
LOG_FILE="/var/log/user_manager.log"

# Функция логирования
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Функция вывода с цветом
print_status() {
    case $1 in
        success) echo -e "${GREEN}[SUCCESS]${NC} $2" ;;
        error) echo -e "${RED}[ERROR]${NC} $2" ;;
        warning) echo -e "${YELLOW}[WARNING]${NC} $2" ;;
        info) echo -e "${BLUE}[INFO]${NC} $2" ;;
    esac
}

# Функция проверки прав sudo
check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        print_status error "Этот скрипт должен запускаться с правами root или через sudo"
        exit 1
    fi
}

# Функция создания пользователя
create_user() {
    echo
    print_status info "=== СОЗДАНИЕ НОВОГО ПОЛЬЗОВАТЕЛЯ ==="
    
    read -p "Введите имя пользователя: " username
    
    # Проверка существования пользователя
    if id "$username" &>/dev/null; then
        print_status error "Пользователь $username уже существует"
        return 1
    fi
    
    # Ввод и проверка пароля
    while true; do
        read -s -p "Введите пароль: " password
        echo
        read -s -p "Повторите пароль: " password_confirm
        echo
        
        if [ "$password" != "$password_confirm" ]; then
            print_status error "Пароли не совпадают"
            continue
        fi
        
        if [ ${#password} -lt 8 ]; then
            print_status warning "Пароль должен быть не менее 8 символов"
            continue
        fi
        
        break
    done
    
    # Создание пользователя
    if useradd -m -s /bin/bash "$username" 2>/dev/null; then
        print_status success "Пользователь $username создан"
    else
        print_status error "Ошибка при создании пользователя"
        return 1
    fi
    
    # Установка пароля
    echo "$username:$password" | chpasswd 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status success "Пароль установлен"
    else
        print_status error "Ошибка при установке пароля"
    fi
    
    # Создание SSH директории
    mkdir -p "/home/$username/.ssh"
    touch "/home/$username/.ssh/authorized_keys"
    chmod 700 "/home/$username/.ssh"
    chmod 600 "/home/$username/.ssh/authorized_keys"
    chown -R "$username:$username" "/home/$username/.ssh"
    
    print_status success "SSH директория настроена"
    
    # Настройка базовых прав
    setup_user_permissions "$username" "user"
    
    log_message "Создан пользователь: $username"
    print_status success "Пользователь $username успешно создан и настроен"
}

# Функция настройки прав пользователя
setup_user_permissions() {
    local username=$1
    local permission_level=$2
    
    case $permission_level in
        admin)
            usermod -aG sudo "$username" 2>/dev/null
            print_status success "Права администратора granted для $username"
            ;;
        user)
            # Удаляем из sudo группы если был там
            gpasswd -d "$username" sudo 2>/dev/null
            print_status success "Обычные права пользователя для $username"
            ;;
        restricted)
            # Блокируем вход по паролю, только SSH ключи
            usermod -s /usr/sbin/nologin "$username" 2>/dev/null
            gpasswd -d "$username" sudo 2>/dev/null
            print_status success "Ограниченные права для $username"
            ;;
    esac
    
    log_message "Права пользователя $username изменены на: $permission_level"
}

# Функция изменения прав пользователя
modify_user_permissions() {
    echo
    print_status info "=== ИЗМЕНЕНИЕ ПРАВ ПОЛЬЗОВАТЕЛЯ ==="
    
    read -p "Введите имя пользователя: " username
    
    # Проверка существования пользователя
    if ! id "$username" &>/dev/null; then
        print_status error "Пользователь $username не существует"
        return 1
    fi
    
    # Проверка домашней директории
    if [ ! -d "/home/$username" ]; then
        print_status warning "Домашняя директория пользователя не найдена"
    fi
    
    echo
    echo "Выберите уровень прав:"
    echo "1) Администратор (sudo права)"
    echo "2) Обычный пользователь"
    echo "3) Ограниченный доступ (только SSH ключи)"
    echo "4) Заблокировать пользователя"
    echo "5) Разблокировать пользователя"
    echo "0) Назад"
    
    read -p "Выберите опцию [0-5]: " permission_choice
    
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
            print_status success "Пользователь $username заблокирован"
            log_message "Пользователь $username заблокирован"
            ;;
        5)
            usermod -U "$username" 2>/dev/null
            print_status success "Пользователь $username разблокирован"
            log_message "Пользователь $username разблокирован"
            ;;
        0)
            return
            ;;
        *)
            print_status error "Неверный выбор"
            return 1
            ;;
    esac
}

# Функция просмотра информации о пользователе
view_user_info() {
    echo
    print_status info "=== ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЕ ==="
    
    read -p "Введите имя пользователя: " username
    
    if ! id "$username" &>/dev/null; then
        print_status error "Пользователь $username не существует"
        return 1
    fi
    
    echo
    echo "Информация о пользователе $username:"
    echo "-----------------------------------"
    id "$username"
    echo
    echo "Группы пользователя:"
    groups "$username"
    echo
    echo "Домашняя директория:"
    ls -ld "/home/$username" 2>/dev/null || echo "Не найдена"
    echo
    echo "Статус блокировки:"
    passwd -S "$username" 2>/dev/null || echo "Не удалось получить статус"
}

# Функция удаления пользователя
delete_user() {
    echo
    print_status info "=== УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ ==="
    
    read -p "Введите имя пользователя для удаления: " username
    
    if ! id "$username" &>/dev/null; then
        print_status error "Пользователь $username не существует"
        return 1
    fi
    
    read -p "Удалить домашнюю директорию? (y/N): " delete_home
    
    echo
    print_status warning "ВНИМАНИЕ: Это действие необратимо!"
    read -p "Вы уверены, что хотите удалить пользователя $username? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_status info "Удаление отменено"
        return
    fi
    
    if [[ "$delete_home" == "y" || "$delete_home" == "Y" ]]; then
        userdel -r "$username" 2>/dev/null
        print_status success "Пользователь $username и домашняя директория удалены"
        log_message "Пользователь $username удален с домашней директорией"
    else
        userdel "$username" 2>/dev/null
        print_status success "Пользователь $username удален (домашняя директория сохранена)"
        log_message "Пользователь $username удален"
    fi
}

# Главное меню
main_menu() {
    while true; do
        echo
        print_status info "=== МЕНЕДЖЕР ПОЛЬЗОВАТЕЛЕЙ UNIX ==="
        echo
        echo "1) Создать нового пользователя"
        echo "2) Изменить права пользователя"
        echo "3) Просмотреть информацию о пользователе"
        echo "4) Удалить пользователя"
        echo "5) Просмотреть лог операций"
        echo "6) Выход"
        echo
        
        read -p "Выберите опцию [1-6]: " choice
        
        case $choice in
            1) create_user ;;
            2) modify_user_permissions ;;
            3) view_user_info ;;
            4) delete_user ;;
            5) 
                echo
                print_status info "=== ЛОГ ОПЕРАЦИЙ ==="
                sudo cat "$LOG_FILE" 2>/dev/null || echo "Лог файл не найден"
                ;;
            6)
                print_status info "Выход..."
                exit 0
                ;;
            *)
                print_status error "Неверный выбор"
                ;;
        esac
        
        read -p "Нажмите Enter для продолжения..."
        clear
    done
}

# Инициализация
initialize() {
    check_sudo
    
    # Создание лог файла если не существует
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 600 "$LOG_FILE"
    fi
    
    clear
    print_status info "Менеджер пользователей запущен"
    log_message "=== Сессия менеджера пользователей начата ==="
}

# Основная логика
initialize
main_menu
