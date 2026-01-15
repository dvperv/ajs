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

    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
    echo "  Создан файл: $file_path"
}

# Создание Go файла с пакетом
create_go_file() {
    local file_path="$1"
    local package_name="$2"
    local content="${3:-}"

    # Всегда начинаем файл с объявления пакета
    local go_content="package $package_name"

    # Если есть дополнительное содержимое, добавляем его через пустую строку
    if [[ -n "$content" ]]; then
        go_content="$go_content"$'\n\n'"$content"
    fi

    create_file "$file_path" "$go_content"
}