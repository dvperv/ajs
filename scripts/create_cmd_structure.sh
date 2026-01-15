#!/bin/bash

# Скрипт для создания структуры cmd/

create_cmd_structure() {
    echo "Создание структуры cmd/..."

    mkdir -p "$BACKEND_DIR/cmd/api"

    # Создание main.go
    cat > "$BACKEND_DIR/cmd/api/main.go" << 'EOF'
package main

import (
    "fmt"
    "log"
)

func main() {
    fmt.Println("AutoJobSearch Backend starting...")
    log.Println("Server is ready")
}
EOF

    echo "  Создан файл: $BACKEND_DIR/cmd/api/main.go"
    echo "Структура cmd/ создана"
}

create_cmd_structure