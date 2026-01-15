#!/bin/bash

# Главный скрипт для создания структуры проекта AutoJobSearch Backend
# Запуск: ./create_backend.sh

set -e

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"

# Экспортируем BACKEND_DIR для дочерних скриптов
export BACKEND_DIR

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."

    # Проверка Go
    if ! command -v go &> /dev/null; then
        log_error "Go не установлен. Требуется версия 1.25.6"
        exit 1
    fi

    GO_VERSION=$(go version | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/go//')
    if [[ "$GO_VERSION" != "1.25.6" ]]; then
        log_warning "Установлена Go $GO_VERSION, рекомендуется 1.25.6"
    fi

    # Проверка директорий
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        log_error "Директория проекта не найдена: $PROJECT_ROOT"
        exit 1
    fi

    log_success "Все зависимости проверены"
}

# Создание структуры проекта
create_project_structure() {
    log_info "Создание структуры проекта..."

    # Создание основной директории бэкенда
    mkdir -p "$BACKEND_DIR"
    log_info "Создана директория: $BACKEND_DIR"

    # Загрузка вспомогательных функций
    source "$SCRIPT_DIR/create_helpers.sh"

    # Создание базовых файлов
    echo "# AutoJobSearch Backend" > "$BACKEND_DIR/README.md"
    echo "1.0.0" > "$BACKEND_DIR/VERSION"

    # Выполнение всех скриптов создания
    local scripts=(
        "setup_go_project.sh"
        "create_configs.sh"
        "create_cmd_structure.sh"
        "create_internal_structure.sh"
        "create_pkg_structure.sh"
        "create_api_docs.sh"
        "create_infrastructure.sh"
        "create_test_structure.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            log_info "Выполнение скрипта: $script"
            if bash "$SCRIPT_DIR/$script"; then
                log_success "Скрипт $script выполнен успешно"
            else
                log_error "Ошибка выполнения скрипта $script"
                exit 1
            fi
        else
            log_error "Скрипт не найден: $script"
            exit 1
        fi
    done

    log_success "Структура проекта создана"
}

# Установка прав
set_permissions() {
    log_info "Установка прав на скрипты..."

    chmod +x "$SCRIPT_DIR"/*.sh
    chmod +x "$BACKEND_DIR"/scripts/*.sh 2>/dev/null || true

    log_success "Права установлены"
}

# Финальная проверка
final_check() {
    log_info "Финальная проверка структуры..."

    # Проверка основных директорий
    local required_dirs=(
        "$BACKEND_DIR/cmd"
        "$BACKEND_DIR/internal"
        "$BACKEND_DIR/pkg"
        "$BACKEND_DIR/api"
        "$BACKEND_DIR/config"
        "$BACKEND_DIR/scripts"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Директория существует: $(get_relative_path "$dir" "$PROJECT_ROOT")"
        else
            log_error "Директория отсутствует: $(get_relative_path "$dir" "$PROJECT_ROOT")"
        fi
    done

    # Проверка основных файлов
    local required_files=(
        "$BACKEND_DIR/go.mod"
        "$BACKEND_DIR/go.sum"
        "$BACKEND_DIR/Makefile"
        "$BACKEND_DIR/Dockerfile"
        "$BACKEND_DIR/.env.example"
    )

    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "Файл существует: $(get_relative_path "$file" "$PROJECT_ROOT")"
        else
            log_error "Файл отсутствует: $(get_relative_path "$file" "$PROJECT_ROOT")"
        fi
    done

    # Подсчет файлов
    local file_count=$(find "$BACKEND_DIR" -type f -name "*.go" 2>/dev/null | wc -l)
    log_info "Создано Go файлов: $file_count"

    local total_count=$(find "$BACKEND_DIR" -type f 2>/dev/null | wc -l)
    log_info "Всего файлов создано: $total_count"
}

# Основная функция
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  AutoJobSearch Backend Project Creator ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    log_info "Начало создания структуры проекта"
    log_info "Рабочая директория: $BACKEND_DIR"

    # Проверка и создание
    check_dependencies
    create_project_structure
    set_permissions
    final_check

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Проект успешно создан!                ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Следующие шаги:"
    echo "1. Настроить переменные окружения в .env файле"
    echo "2. Выполнить: cd $BACKEND_DIR"
    echo "3. Запустить: make deps"
    echo "4. Запустить: make run"
    echo ""
    echo "Для получения помощи: make help"
}

# Запуск основной функции
main "$@"