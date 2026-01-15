#!/bin/bash

# Скрипт для создания конфигурационных файлов
# Запуск: ./create_configs.sh

source "$(dirname "$0")/create_helpers.sh"

create_configs() {
    echo "========================================"
    echo "Создание конфигурационных файлов..."
    echo "========================================"

    # Создание директории config
    create_dir "$BACKEND_DIR/config"

    # Создание config.go
    create_go_file "$BACKEND_DIR/config/config.go" "config" "$(cat <<'EOF'
package config

import (
    "os"
    "strconv"
    "time"
)

type Config struct {
    Server      ServerConfig
    Database    DatabaseConfig
    Redis       RedisConfig
    RabbitMQ    RabbitMQConfig
    Encryption  EncryptionConfig
    HH          HHConfig
    RateLimit   RateLimitConfig
    ML          MLConfig
}

type ServerConfig struct {
    Port            string
    Env             string
    JWTSecret       string
    JWTExpiry       time.Duration
    ShutdownTimeout time.Duration
}

type DatabaseConfig struct {
    Host            string
    Port            string
    User            string
    Password        string
    Name            string
    SSLMode         string
    MaxConns        int
    MaxIdleConns    int
    ConnMaxLifetime time.Duration
}

type RedisConfig struct {
    Host     string
    Port     string
    Password string
    DB       int
}

type RabbitMQConfig struct {
    URL      string
    Exchange string
    Queue    string
}

type EncryptionConfig struct {
    MasterKey  string
    Algorithm  string
    IVLength   int
}

type HHConfig struct {
    ClientID     string
    ClientSecret string
    RedirectURI  string
    APIURL       string
    AuthURL      string
    TokenURL     string
}

type RateLimitConfig struct {
    RequestsPerMinute int
    Burst             int
}

type MLConfig struct {
    ModelPath      string
    CacheSize      int
    DownloadURL    string
    ModelSignature string
}

func Load() (*Config, error) {
    return &Config{
        Server: ServerConfig{
            Port:            getEnv("PORT", "8080"),
            Env:             getEnv("ENV", "development"),
            JWTSecret:       getEnv("JWT_SECRET", "your-super-secret-jwt-key-min-32-chars"),
            JWTExpiry:       time.Hour * 24 * 7,
            ShutdownTimeout: time.Second * 10,
        },
        Database: DatabaseConfig{
            Host:            getEnv("DB_HOST", "localhost"),
            Port:            getEnv("DB_PORT", "5432"),
            User:            getEnv("DB_USER", "postgres"),
            Password:        getEnv("DB_PASSWORD", "postgres"),
            Name:            getEnv("DB_NAME", "autojobsearch"),
            SSLMode:         getEnv("DB_SSLMODE", "disable"),
            MaxConns:        getEnvAsInt("DB_MAX_CONNS", 25),
            MaxIdleConns:    getEnvAsInt("DB_MAX_IDLE_CONNS", 5),
            ConnMaxLifetime: time.Hour,
        },
        Redis: RedisConfig{
            Host:     getEnv("REDIS_HOST", "localhost"),
            Port:     getEnv("REDIS_PORT", "6379"),
            Password: getEnv("REDIS_PASSWORD", ""),
            DB:       getEnvAsInt("REDIS_DB", 0),
        },
        Encryption: EncryptionConfig{
            MasterKey: getEnv("ENCRYPTION_MASTER_KEY", ""),
            Algorithm: "AES-256-GCM",
            IVLength:  12,
        },
        HH: HHConfig{
            ClientID:     getEnv("HH_CLIENT_ID", ""),
            ClientSecret: getEnv("HH_CLIENT_SECRET", ""),
            RedirectURI:  getEnv("HH_REDIRECT_URI", "http://localhost:8080/auth/hh/callback"),
            APIURL:       "https://api.hh.ru",
            AuthURL:      "https://hh.ru/oauth/authorize",
            TokenURL:     "https://hh.ru/oauth/token",
        },
        RateLimit: RateLimitConfig{
            RequestsPerMinute: getEnvAsInt("RATE_LIMIT_REQUESTS", 60),
            Burst:             getEnvAsInt("RATE_LIMIT_BURST", 10),
        },
        ML: MLConfig{
            ModelPath:      getEnv("ML_MODEL_PATH", "./models"),
            CacheSize:      getEnvAsInt("ML_CACHE_SIZE", 100),
            DownloadURL:    getEnv("ML_MODEL_URL", "https://models.autojobsearch.com"),
            ModelSignature: getEnv("ML_MODEL_SIGNATURE", ""),
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
)"

    echo "✅ Конфигурационные файлы созданы"
}

# Проверка переменных окружения
if [[ -z "$BACKEND_DIR" ]]; then
    echo "Ошибка: BACKEND_DIR не определена"
    echo "Запустите скрипт через create_backend.sh"
    exit 1
fi

# Запуск функции
create_configs