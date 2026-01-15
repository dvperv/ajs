#!/bin/bash

# Скрипт для создания структуры тестов

create_test_structure() {
    echo "Создание структуры тестов..."

    mkdir -p "$BACKEND_DIR/tests/unit"

    cat > "$BACKEND_DIR/tests/unit/service_test.go" << 'EOF'
package unit

import "testing"

func TestExample(t *testing.T) {
    if 1+1 != 2 {
        t.Error("Math is broken")
    }
}
EOF
    echo "  Создан файл: tests/unit/service_test.go"

    echo "Структура тестов создана"
}

create_test_structure