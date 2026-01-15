#!/bin/bash

# Главный скрипт для создания структуры проекта AutoJobSearch Backend
# Запуск: ./create_backend.sh

set -e

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"

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

    if ! command -v go &> /dev/null; then
        log_error "Go не установлен. Требуется версия 1.25.6"
        exit 1
    fi

    GO_VERSION=$(go version | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/go//')
    log_info "Установлена Go версии: $GO_VERSION"

    if [[ ! -d "$PROJECT_ROOT" ]]; then
        log_error "Директория проекта не найдена: $PROJECT_ROOT"
        exit 1
    fi

    log_success "Все зависимости проверены"
}

# Создание структуры проекта
create_project_structure() {
    log_info "Создание структуры проекта..."

    mkdir -p "$BACKEND_DIR"
    log_info "Создана директория: $BACKEND_DIR"

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
        local script_path="$SCRIPT_DIR/$script"
        if [[ -f "$script_path" ]]; then
            log_info "Выполнение скрипта: $script"
            # Источник вспомогательных функций для каждого скрипта
            export BACKEND_DIR SCRIPT_DIR PROJECT_ROOT
            bash "$script_path"
        else
            log_error "Скрипт не найден: $script"
        fi
    done

    log_success "Структура проекта создана"
}

# Установка прав
set_permissions() {
    log_info "Установка прав на скрипты..."
    chmod +x "$SCRIPT_DIR"/*.sh
    log_success "Права установлены"
}

# Финальная проверка
final_check() {
    log_info "Финальная проверка структуры..."

    local required_dirs=(
        "$BACKEND_DIR/cmd"
        "$BACKEND_DIR/internal"
        "$BACKEND_DIR/pkg"
        "$BACKEND_DIR/api"
        "$BACKEND_DIR/config"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Директория существует: $(basename "$dir")"
        else
            log_error "Директория отсутствует: $(basename "$dir")"
        fi
    done

    local file_count=$(find "$BACKEND_DIR" -type f -name "*.go" 2>/dev/null | wc -l)
    log_info "Создано Go файлов: $file_count"
}

# Основная функция
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  AutoJobSearch Backend Project Creator ${NC}"
    echo -e "${BLUE}========================================${NC}"

    check_dependencies
    create_project_structure
    set_permissions
    final_check

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Проект успешно создан!                ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Структура создана в: $BACKEND_DIR"
}

main "$@"