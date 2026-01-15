#!/bin/bash

# Скрипт для создания конфигурационных файлов

create_configs() {
    echo "Создание конфигурационных файлов..."

    mkdir -p "$BACKEND_DIR/config"

    # Создание config.go
    cat > "$BACKEND_DIR/config/config.go" << 'EOF'
package config

import (
    "os"
    "strconv"
    "time"
)

type Config struct {
    Server      ServerConfig
    Database    DatabaseConfig
}

type ServerConfig struct {
    Port            string
    Env             string
}

type DatabaseConfig struct {
    Host            string
    Port            string
    User            string
    Password        string
    Name            string
}

func Load() (*Config, error) {
    return &Config{
        Server: ServerConfig{
            Port: getEnv("PORT", "8080"),
            Env:  getEnv("ENV", "development"),
        },
        Database: DatabaseConfig{
            Host: getEnv("DB_HOST", "localhost"),
            Port: getEnv("DB_PORT", "5432"),
        },
    }, nil
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intVal, err := strconv.Atoi(value); err == nil {
            return intVal
        }
    }
    return defaultValue
}
EOF

    echo "  Создан файл: $BACKEND_DIR/config/config.go"
    echo "Конфигурационные файлы созданы"
}

create_configs