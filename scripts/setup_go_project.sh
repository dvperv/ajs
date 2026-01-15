#!/bin/bash

# Скрипт для настройки Go проекта

# source "$(dirname "$0")/create_helpers.sh" # Убрано, чтобы избежать циклических вызовов

setup_go_project() {
    echo "Настройка Go проекта..."
    
    cd "$BACKEND_DIR" || exit 1
    
    if [[ ! -f "go.mod" ]]; then
        echo "  Инициализация Go модуля..."
        go mod init autojobsearch/backend
    else
        echo "  Go модуль уже инициализирован"
    fi
    
    touch go.sum
    
    # Создание Makefile (сокращенная версия для примера)
    cat > Makefile << 'EOF'
.PHONY: help deps build run

help:
	@echo "Доступные команды:"

deps:
	go mod download

build:
	go build -o bin/api ./cmd/api

run:
	go run ./cmd/api
EOF
    echo "  Создан файл: Makefile"
    
    # Создание .env.example
    cat > .env.example << 'EOF'
PORT=8080
DB_HOST=localhost
DB_PASSWORD=postgres
EOF
    echo "  Создан файл: .env.example"
    
    echo "Настройка Go проекта завершена"
}

# Явно задаем переменные, если они не установлены (для отладки)
if [[ -z "$BACKEND_DIR" ]]; then
    echo "Ошибка: BACKEND_DIR не установлена" >&2
    exit 1
fi

setup_go_project