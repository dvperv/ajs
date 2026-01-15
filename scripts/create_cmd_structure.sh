#!/bin/bash

# Скрипт для создания структуры cmd/

source "$(dirname "$0")/create_helpers.sh"

create_cmd_structure() {
    echo "Создание структуры cmd/..."

    # Создание директории cmd/api
    create_dir "$BACKEND_DIR/cmd/api"

    # Создание main.go
    create_go_file "$BACKEND_DIR/cmd/api/main.go" "main" "$(cat <<'EOF'
import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "autojobsearch/backend/config"
    "autojobsearch/backend/internal/app"
    "autojobsearch/backend/pkg/logger"
)

func main() {
    // Загрузка конфигурации
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }

    // Инициализация логгера
    logger.Init(cfg.Server.Env)

    // Создание приложения
    application, err := app.New(cfg)
    if err != nil {
        logger.Fatalf("Failed to create app: %v", err)
    }

    // Запуск фоновых задач
    go application.StartBackgroundTasks()

    // Настройка HTTP сервера
    srv := &http.Server{
        Addr:         ":" + cfg.Server.Port,
        Handler:      application.Router(),
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 30 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    // Graceful shutdown
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            logger.Fatalf("Server failed: %v", err)
        }
    }()

    logger.Infof("Server started on port %s", cfg.Server.Port)

    // Ожидание сигналов
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Info("Shutting down server...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        logger.Fatalf("Server forced to shutdown: %v", err)
    }

    application.StopBackgroundTasks()
    logger.Info("Server stopped gracefully")
}
EOF
)"

    echo "Структура cmd/ создана"
}

# Запуск функции
create_cmd_structure