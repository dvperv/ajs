#!/bin/bash

# Скрипт для создания структуры internal/

create_internal_structure() {
    echo "Создание структуры internal/..."

    mkdir -p "$BACKEND_DIR/internal/app"
    mkdir -p "$BACKEND_DIR/internal/domain/models"
    mkdir -p "$BACKEND_DIR/internal/handler"

    # Создаем несколько основных файлов вместо всех сразу
    cat > "$BACKEND_DIR/internal/app/app.go" << 'EOF'
package app

type App struct {
    // Базовая структура приложения
}
EOF
    echo "  Создан файл: internal/app/app.go"

    cat > "$BACKEND_DIR/internal/domain/models/user.go" << 'EOF'
package models

type User struct {
    ID    string `json:"id"`
    Email string `json:"email"`
}
EOF
    echo "  Создан файл: internal/domain/models/user.go"

    echo "Структура internal/ создана"
}

create_internal_structure