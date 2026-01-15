#!/bin/bash

# Скрипт для создания API документации

create_api_docs() {
    echo "Создание API документации..."

    mkdir -p "$BACKEND_DIR/api"

    cat > "$BACKEND_DIR/README.md" << 'EOF'
# AutoJobSearch Backend

## Быстрый старт

```bash
make run