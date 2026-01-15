                #!/bin/bash

                # Скрипт для настройки Go проекта

                source "$(dirname "$0")/create_helpers.sh"

                setup_go_project() {
                    echo "========================================"
                    echo "Настройка Go проекта..."
                    echo "========================================"

                    cd "$BACKEND_DIR"

                    # 1. Инициализация Go модуля
                    echo "1. Инициализация Go модуля..."

                    if [[ ! -f "go.mod" ]]; then
                        echo "  Создание go.mod..."
                        go mod init autojobsearch/backend
                        echo "  ✅ Go модуль инициализирован"
                    else
                        echo "  ✅ Go модуль уже существует"
                    fi

                    # 2. Создание go.sum (будет создан автоматически при go mod tidy)
                    echo "2. Настройка зависимостей..."

                    # Создание временного файла с зависимостями
                    cat > go.mod.tmp << 'EOF'
                module autojobsearch/backend

                go 1.25.6

                require (
                    github.com/gin-gonic/gin v1.10.0
                    github.com/lib/pq v1.10.9
                    github.com/jmoiron/sqlx v1.4.0
                    github.com/go-redis/redis/v8 v8.11.5
                    github.com/rabbitmq/amqp091-go v1.10.0
                    github.com/google/uuid v1.6.0
                    github.com/golang-jwt/jwt/v5 v5.2.1
                    go.uber.org/zap v1.27.0
                    github.com/swaggo/swag v1.16.3
                    github.com/swaggo/gin-swagger v1.6.0
                    github.com/gin-contrib/cors v1.7.2
                    github.com/pressly/goose/v3 v3.20.0
                    github.com/golang-migrate/migrate/v4 v4.17.1
                    github.com/stretchr/testify v1.9.0
                    github.com/rs/zerolog v1.32.0
                    github.com/gorilla/websocket v1.5.3
                    github.com/joho/godotenv v1.5.1
                    golang.org/x/crypto v0.24.0
                    golang.org/x/sync v0.7.0
                )

                require (
                    github.com/bytedance/sonic v1.11.6 // indirect
                    github.com/bytedance/sonic/loader v0.1.1 // indirect
                    github.com/cloudwego/base64x v0.1.4 // indirect
                    github.com/cloudwego/iasm v0.2.0 // indirect
                    github.com/davecgh/go-spew v1.1.1 // indirect
                    github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
                    github.com/gabriel-vasile/mimetype v1.4.3 // indirect
                    github.com/gin-contrib/sse v0.1.0 // indirect
                    github.com/go-playground/locales v0.14.1 // indirect
                    github.com/go-playground/universal-translator v0.18.1 // indirect
                    github.com/go-playground/validator/v10 v10.20.0 // indirect
                    github.com/goccy/go-json v0.10.2 // indirect
                    github.com/hashicorp/errwrap v1.1.0 // indirect
                    github.com/hashicorp/go-multierror v1.1.1 // indirect
                    github.com/json-iterator/go v1.1.12 // indirect
                    github.com/klauspost/cpuid/v2 v2.2.7 // indirect
                    github.com/kr/text v0.2.0 // indirect
                    github.com/leodido/go-urn v1.4.0 // indirect
                    github.com/mattn/go-colorable v0.1.13 // indirect
                    github.com/mattn/go-isatty v0.0.20 // indirect
                    github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
                    github.com/modern-go/reflect2 v1.0.2 // indirect
                    github.com/pelletier/go-toml/v2 v2.2.2 // indirect
                    github.com/pmezard/go-difflib v1.0.0 // indirect
                    github.com/twitchyliquid64/golang-asm v0.15.1 // indirect
                    github.com/ugorji/go/codec v1.2.12 // indirect
                    go.uber.org/atomic v1.11.0 // indirect
                    go.uber.org/multierr v1.11.0 // indirect
                    golang.org/x/arch v0.8.0 // indirect
                    golang.org/x/net v0.26.0 // indirect
                    golang.org/x/sys v0.21.0 // indirect
                    golang.org/x/text v0.16.0 // indirect
                    golang.org/x/tools v0.22.0 // indirect
                    google.golang.org/protobuf v1.34.2 // indirect
                    gopkg.in/yaml.v3 v3.0.1 // indirect
                )
                EOF

                    # Объединяем с существующим go.mod если есть
                    if [[ -f "go.mod" ]]; then
                        # Сохраняем существующий module declaration
                        head -n 2 go.mod > go.mod.new
                        cat go.mod.tmp | tail -n +4 >> go.mod.new
                        mv go.mod.new go.mod
                    else
                        mv go.mod.tmp go.mod
                    fi

                    rm -f go.mod.tmp

                    # 3. Скачивание зависимостей
                    echo "3. Скачивание зависимостей..."
                    go mod download
                    go mod tidy

                    echo "  ✅ Зависимости установлены"

                    # 4. Создание основных файлов проекта
                    echo "4. Создание основных файлов проекта..."

                    # Makefile
                    create_file "Makefile" "$(cat <<'EOF'
                .PHONY: help deps build test lint run clean migrate docker-build docker-run db-check

                # Help
                help:
                	@echo "Доступные команды:"
                	@echo "  make help        - Показать это сообщение"
                	@echo "  make deps        - Установка зависимостей"
                	@echo "  make build       - Сборка проекта"
                	@echo "  make test        - Запуск тестов"
                	@echo "  make lint        - Проверка кода"
                	@echo "  make run         - Запуск в режиме разработки"
                	@echo "  make run-prod    - Запуск в продакшен режиме"
                	@echo "  make clean       - Очистка"
                	@echo "  make migrate     - Запуск миграций"
                	@echo "  make migrate-status - Статус миграций"
                	@echo "  make docker-build - Сборка Docker образа"
                	@echo "  make docker-run  - Запуск в Docker"
                	@echo "  make db-check    - Проверка подключения к БД"
                	@echo "  make swagger     - Генерация Swagger документации"

                # Установка зависимостей
                deps:
                	@echo "Установка зависимостей..."
                	go mod download
                	go install github.com/swaggo/swag/cmd/swag@latest
                	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
                	go install github.com/pressly/goose/v3/cmd/goose@latest
                	@echo "✅ Зависимости установлены"

                # Генерация Swagger документации
                swagger:
                	@echo "Генерация Swagger документации..."
                	swag init -g cmd/api/main.go -o api/swagger
                	@echo "✅ Swagger документация сгенерирована"

                # Сборка
                build:
                	@echo "Сборка проекта..."
                	go build -ldflags="-s -w" -o bin/api ./cmd/api
                	@echo "✅ Проект собран: bin/api"

                # Тесты
                test:
                	@echo "Запуск тестов..."
                	go test ./... -v -cover -coverprofile=coverage.out
                	@echo "✅ Тесты завершены"

                # Coverage report
                coverage:
                	@echo "Генерация отчета покрытия..."
                	go tool cover -html=coverage.out -o coverage.html
                	@echo "✅ Отчет coverage.html создан"

                # Линтинг
                lint:
                	@echo "Проверка кода..."
                	golangci-lint run ./...
                	@echo "✅ Линтинг завершен"

                # Запуск в режиме разработки
                run:
                	@echo "Запуск в режиме разработки..."
                	go run ./cmd/api

                # Запуск в продакшен режиме
                run-prod:
                	@echo "Запуск в продакшен режиме..."
                	ENV=production go run ./cmd/api

                # Очистка
                clean:
                	@echo "Очистка..."
                	rm -rf bin/ coverage.out coverage.html
                	@echo "✅ Очистка завершена"

                # Миграции
                migrate:
                	@echo "Запуск миграций..."
                	goose -dir internal/infrastructure/database/migrations postgres "${DB_CONN_STRING}" up
                	@echo "✅ Миграции применены"

                migrate-down:
                	@echo "Откат миграции..."
                	goose -dir internal/infrastructure/database/migrations postgres "${DB_CONN_STRING}" down
                	@echo "✅ Миграция откачена"

                migrate-status:
                	@echo "Статус миграций:"
                	goose -dir internal/infrastructure/database/migrations postgres "${DB_CONN_STRING}" status

                # Проверка БД
                db-check:
                	@echo "Проверка подключения к БД..."
                	@if [ -z "${DB_CONN_STRING}" ]; then \
                		echo "❌ DB_CONN_STRING не установлена"; \
                		echo "Установите переменную: export DB_CONN_STRING=postgres://user:pass@localhost:5432/dbname"; \
                		exit 1; \
                	fi
                	@if goose -dir internal/infrastructure/database/migrations postgres "${DB_CONN_STRING}" status > /dev/null 2>&1; then \
                		echo "✅ Подключение к БД успешно"; \
                	else \
                		echo "❌ Не удалось подключиться к БД"; \
                		exit 1; \
                	fi

                # Docker сборка
                docker-build:
                	@echo "Сборка Docker образа..."
                	docker build -t autojobsearch/backend:latest .
                	@echo "✅ Docker образ собран"

                # Docker запуск
                docker-run:
                	@echo "Запуск в Docker..."
                	docker run -p 8080:8080 --env-file .env autojobsearch/backend:latest

                # Docker compose
                compose-up:
                	@echo "Запуск Docker Compose..."
                	docker-compose -f docker-compose.production.yml up -d

                compose-down:
                	@echo "Остановка Docker Compose..."
                	docker-compose -f docker-compose.production.yml down

                compose-logs:
                	@echo "Логи Docker Compose..."
                	docker-compose -f docker-compose.production.yml logs -f
                EOF
                )"

                    # Dockerfile
                    create_file "Dockerfile" "$(cat <<'EOF'
                # Builder stage
                FROM golang:1.25.6-alpine AS builder

                WORKDIR /app

                # Установка системных зависимостей
                RUN apk add --no-cache git gcc musl-dev ca-certificates tzdata

                # Копирование go модулей
                COPY go.mod go.sum ./
                RUN go mod download

                # Копирование исходного кода
                COPY . .

                # Сборка приложения
                RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
                    go build -ldflags="-s -w -extldflags '-static'" \
                    -a -installsuffix cgo -o main ./cmd/api

                # Final stage
                FROM alpine:3.19

                RUN apk --no-cache add ca-certificates tzdata

                WORKDIR /root/

                # Копирование бинарного файла из builder
                COPY --from=builder /app/main .

                # Копирование конфигураций
                COPY --from=builder /app/.env.example .env.example
                COPY --from=builder /app/internal/infrastructure/database/migrations ./migrations
                COPY --from=builder /app/scripts ./scripts

                # Создание пользователя
                RUN addgroup -g 1001 -S appuser && \
                    adduser -u 1001 -S appuser -G appuser && \
                    chown -R appuser:appuser /root

                USER appuser

                # Экспорт порта
                EXPOSE 8080

                # Health check
                HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
                    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

                # Запуск приложения
                CMD ["./main"]
                EOF
                )"

                    # docker-compose.production.yml
                    create_file "docker-compose.production.yml" "$(cat <<'EOF'
                version: '3.8'

                services:
                  postgres:
                    image: postgres:15-alpine
                    container_name: autojobsearch-postgres
                    environment:
                      POSTGRES_DB: ${DB_NAME:-autojobsearch}
                      POSTGRES_USER: ${DB_USER:-postgres}
                      POSTGRES_PASSWORD: ${DB_PASSWORD:-postgres}
                    ports:
                      - "5432:5432"
                    volumes:
                      - postgres_data:/var/lib/postgresql/data
                      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
                    healthcheck:
                      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-postgres}"]
                      interval: 10s
                      timeout: 5s
                      retries: 5
                    networks:
                      - autojobsearch-network

                  redis:
                    image: redis:7-alpine
                    container_name: autojobsearch-redis
                    ports:
                      - "6379:6379"
                    command: redis-server --requirepass ${REDIS_PASSWORD:-}
                    volumes:
                      - redis_data:/data
                    healthcheck:
                      test: ["CMD", "redis-cli", "ping"]
                      interval: 10s
                      timeout: 5s
                      retries: 5
                    networks:
                      - autojobsearch-network

                  rabbitmq:
                    image: rabbitmq:3.12-management-alpine
                    container_name: autojobsearch-rabbitmq
                    environment:
                      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER:-guest}
                      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-guest}
                    ports:
                      - "5672:5672"
                      - "15672:15672"
                    volumes:
                      - rabbitmq_data:/var/lib/rabbitmq
                    healthcheck:
                      test: ["CMD", "rabbitmq-diagnostics", "ping"]
                      interval: 30s
                      timeout: 10s
                      retries: 5
                    networks:
                      - autojobsearch-network

                  backend:
                    build: .
                    container_name: autojobsearch-backend
                    depends_on:
                      postgres:
                        condition: service_healthy
                      redis:
                        condition: service_healthy
                      rabbitmq:
                        condition: service_healthy
                    environment:
                      - ENV=production
                    ports:
                      - "8080:8080"
                    volumes:
                      - ./logs:/app/logs
                      - ./models:/app/models
                    restart: unless-stopped
                    networks:
                      - autojobsearch-network

                  grafana:
                    image: grafana/grafana:latest
                    container_name: autojobsearch-grafana
                    ports:
                      - "3000:3000"
                    environment:
                      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin123}
                      GF_INSTALL_PLUGINS: grafana-piechart-panel
                    volumes:
                      - grafana_data:/var/lib/grafana
                    depends_on:
                      - backend
                    networks:
                      - autojobsearch-network

                  prometheus:
                    image: prom/prometheus:latest
                    container_name: autojobsearch-prometheus
                    ports:
                      - "9090:9090"
                    volumes:
                      - ./prometheus.yml:/etc/prometheus/prometheus.yml
                      - prometheus_data:/prometheus
                    command:
                      - '--config.file=/etc/prometheus/prometheus.yml'
                      - '--storage.tsdb.path=/prometheus'
                      - '--web.console.libraries=/etc/prometheus/console_libraries'
                      - '--web.console.templates=/etc/prometheus/consoles'
                      - '--storage.tsdb.retention.time=200h'
                      - '--web.enable-lifecycle'
                    restart: unless-stopped
                    networks:
                      - autojobsearch-network

                volumes:
                  postgres_data:
                  redis_data:
                  rabbitmq_data:
                  grafana_data:
                  prometheus_data:

                networks:
                  autojobsearch-network:
                    driver: bridge
                EOF
                )"

                    # .env.example
                    create_file ".env.example" "$(cat <<'EOF'
                # Server Configuration
                PORT=8080
                ENV=development
                JWT_SECRET=your-super-secret-jwt-key-min-32-chars-change-in-production
                JWT_EXPIRY=168h # 7 days

                # Database Configuration
                DB_HOST=localhost
                DB_PORT=5432
                DB_USER=postgres
                DB_PASSWORD=postgres
                DB_NAME=autojobsearch
                DB_SSLMODE=disable
                DB_MAX_CONNS=25
                DB_MAX_IDLE_CONNS=5
                DB_CONN_STRING=postgres://postgres:postgres@localhost:5432/autojobsearch?sslmode=disable

                # Redis Configuration
                REDIS_HOST=localhost
                REDIS_PORT=6379
                REDIS_PASSWORD=
                REDIS_DB=0

                # RabbitMQ Configuration
                RABBITMQ_URL=amqp://guest:guest@localhost:5672/
                RABBITMQ_EXCHANGE=autojobsearch
                RABBITMQ_QUEUE=jobs
                RABBITMQ_USER=guest
                RABBITMQ_PASSWORD=guest

                # Encryption
                ENCRYPTION_MASTER_KEY=your-32-byte-master-key-for-encryption-change-this
                ENCRYPTION_ALGORITHM=AES-256-GCM

                # HH.ru OAuth
                HH_CLIENT_ID=your_client_id_here
                HH_CLIENT_SECRET=your_client_secret_here
                HH_REDIRECT_URI=http://localhost:8080/auth/hh/callback

                # Rate Limiting
                RATE_LIMIT_REQUESTS=60
                RATE_LIMIT_BURST=10

                # ML Configuration
                ML_MODEL_PATH=./models
                ML_CACHE_SIZE=100
                ML_MODEL_URL=https://models.autojobsearch.com
                ML_MODEL_SIGNATURE=model_signature_here

                # Monitoring
                GRAFANA_PASSWORD=admin123
                PROMETHEUS_ENABLED=true

                # Application Settings
                LOG_LEVEL=info
                CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
                MAX_REQUEST_BODY_SIZE=10485760 # 10MB
                EOF
                )"

                    # .gitignore
                    create_gitignore ".gitignore"

                    # LICENSE
                    create_license_file "LICENSE"

                    # VERSION файл
                    echo "1.0.0" > "VERSION"

                    # README.md
                    create_file "README.md" "$(cat <<'EOF'
                # AutoJobSearch Backend

                Бэкенд для системы автоматического поиска работы с полной приватностью данных.

                ## 🚀 Быстрый старт

                ### Требования
                - Go 1.25.6
                - PostgreSQL 15+
                - Redis 7+
                - RabbitMQ 3.12+

                ### Установка
                ```bash
                # Клонирование репозитория
                git clone https://github.com/dvperv/autojobsearch.git
                cd autojobsearch/backend

                # Настройка окружения
                cp .env.example .env
                # Отредактируйте .env файл

                # Установка зависимостей
                make deps

                # Запуск инфраструктуры
                docker-compose -f docker-compose.production.yml up -d postgres redis rabbitmq

                # Миграции базы данных
                make migrate

                # Запуск сервера
                make run