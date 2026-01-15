#!/bin/bash

# Скрипт для создания структуры pkg/

create_pkg_structure() {
    echo "Создание структуры pkg/..."

    mkdir -p "$BACKEND_DIR/pkg/logger"
    mkdir -p "$BACKEND_DIR/pkg/utils"

    cat > "$BACKEND_DIR/pkg/logger/logger.go" << 'EOF'
package logger

import "log"

func Info(msg string) {
    log.Printf("INFO: %s", msg)
}
EOF
    echo "  Создан файл: pkg/logger/logger.go"

    cat > "$BACKEND_DIR/pkg/utils/crypto.go" << 'EOF'
package utils

import "crypto/rand"

func GenerateRandomString(length int) string {
    bytes := make([]byte, length)
    rand.Read(bytes)
    return string(bytes)
}
EOF
    echo "  Создан файл: pkg/utils/crypto.go"

    echo "Структура pkg/ создана"
}

create_pkg_structure