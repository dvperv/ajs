#!/bin/bash

# Вспомогательные функции для создания проекта

# Создание директории с проверкой
create_dir() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1"
        echo "  Создана директория: $1"
    fi
}

# Создание файла с содержимым
create_file() {
    local file_path="$1"
    local content="$2"

    # Создание родительских директорий
    mkdir -p "$(dirname "$file_path")"

    # Запись содержимого
    echo "$content" > "$file_path"

    echo "  Создан файл: $file_path"
}

# Создание Go файла с пакетом
create_go_file() {
    local file_path="$1"
    local package_name="$2"
    local content="${3:-}"

    local go_content="package $package_name"

    if [[ -n "$content" ]]; then
        go_content="$go_content\n\n$content"
    fi

    create_file "$file_path" "$go_content"
}

# Создание файла с лицензией MIT
create_license_file() {
    local file_path="$1"
    local author="${2:-AutoJobSearch Team}"
    local year="${3:-$(date +%Y)}"

    local license_content=$(cat <<EOF
MIT License

Copyright (c) $year $author

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
)

    create_file "$file_path" "$license_content"
}

# Проверка существования файла
file_exists() {
    [[ -f "$1" ]] && return 0 || return 1
}

# Проверка существования директории
dir_exists() {
    [[ -d "$1" ]] && return 0 || return 1
}

# Получение относительного пути
get_relative_path() {
    python3 -c "import os.path; print(os.path.relpath('$1', '$2'))" 2>/dev/null || \
    realpath --relative-to="$2" "$1" 2>/dev/null || \
    echo "$1"
}

# Форматирование Go кода
format_go_code() {
    local dir="$1"

    if command -v gofmt &> /dev/null; then
        echo "  Форматирование Go кода в $dir"
        gofmt -w "$dir" 2>/dev/null || true
    fi
}

# Создание .gitignore файла
create_gitignore() {
    local file_path="$1"

    local gitignore_content=$(cat <<EOF
# Binaries
bin/
dist/

# Dependencies
vendor/
node_modules/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# Logs
*.log
logs/

# Coverage
coverage.out
coverage.html

# Build artifacts
*.exe
*.dll
*.so
*.dylib

# Test artifacts
_test.go
*.test
EOF
)

    create_file "$file_path" "$gitignore_content"
}