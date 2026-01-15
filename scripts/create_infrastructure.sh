#!/bin/bash

# Скрипт для создания инфраструктурных файлов
# Запуск: ./create_infrastructure.sh

source "$(dirname "$0")/create_helpers.sh"

create_infrastructure() {
    echo "========================================"
    echo "Создание инфраструктурных файлов..."
    echo "========================================"

    # Создание директорий инфраструктуры
    echo "Создание структуры директорий..."

    create_dir "$BACKEND_DIR/internal/infrastructure/database"
    create_dir "$BACKEND_DIR/internal/infrastructure/database/migrations"
    create_dir "$BACKEND_DIR/internal/infrastructure/queue"
    create_dir "$BACKEND_DIR/internal/infrastructure/cache"
    create_dir "$BACKEND_DIR/internal/infrastructure/encryption"
    create_dir "$BACKEND_DIR/internal/infrastructure/ml"
    create_dir "$BACKEND_DIR/scripts"

    echo "✅ Структура директорий создана"
    echo ""

    # 1. СОЗДАНИЕ МИГРАЦИЙ БАЗЫ ДАННЫХ
    echo "1. Создание миграций базы данных..."

    # Миграция вверх
    create_file "$BACKEND_DIR/internal/infrastructure/database/migrations/001_init_schema.up.sql" "$(cat <<'EOF'
-- Таблица пользователей
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    two_fa_enabled BOOLEAN DEFAULT false,
    two_fa_method VARCHAR(50),
    biometric_key TEXT,
    encryption_key TEXT NOT NULL,

    -- Квоты поиска
    daily_limit INTEGER DEFAULT 1,
    used_today INTEGER DEFAULT 0,
    last_search_time TIMESTAMP WITH TIME ZONE,
    reset_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP + INTERVAL '1 day',

    device_id VARCHAR(255),

    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Таблица резюме
CREATE TABLE resumes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    parsed_data JSONB NOT NULL,
    raw_text TEXT,
    file_url TEXT,
    file_hash VARCHAR(64),
    parsing_accuracy DECIMAL(3,2),
    source_type VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1,

    INDEX idx_resumes_user_id (user_id),
    INDEX idx_resumes_is_active (is_active)
);

-- Таблица вакансий
CREATE TABLE vacancies (
    id VARCHAR(50) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    company VARCHAR(255) NOT NULL,
    salary_from INTEGER,
    salary_to INTEGER,
    salary_currency VARCHAR(10),
    experience VARCHAR(100),
    employment_type VARCHAR(100),
    schedule VARCHAR(100),
    description TEXT,
    key_skills JSONB DEFAULT '[]',
    requirements TEXT,
    responsibility TEXT,
    published_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_new BOOLEAN DEFAULT true,
    is_archived BOOLEAN DEFAULT false,
    source VARCHAR(50) NOT NULL,
    raw_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_vacancies_user_id (user_id),
    INDEX idx_vacancies_published_at (published_at),
    INDEX idx_vacancies_is_new (is_new),
    INDEX idx_vacancies_company (company)
);

-- Таблица настроек поиска
CREATE TABLE search_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    config JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(user_id, name),
    INDEX idx_search_configs_user_id (user_id)
);

-- Таблица откликов
CREATE TABLE applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vacancy_id VARCHAR(50) NOT NULL,
    resume_id UUID NOT NULL REFERENCES resumes(id),
    cover_letter TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    response_received_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,

    FOREIGN KEY (vacancy_id) REFERENCES vacancies(id),
    INDEX idx_applications_user_id (user_id),
    INDEX idx_applications_vacancy_id (vacancy_id),
    INDEX idx_applications_status (status),
    UNIQUE(user_id, vacancy_id)
);

-- Таблица токенов HH.ru
CREATE TABLE hh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    scope TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_hh_tokens_user_id (user_id),
    INDEX idx_hh_tokens_expires_at (expires_at)
);

-- Таблица логов аудита
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_audit_logs_user_id (user_id),
    INDEX idx_audit_logs_action (action),
    INDEX idx_audit_logs_created_at (created_at)
);

-- Таблица синхронизации (CRDT)
CREATE TABLE sync_operations (
    id VARCHAR(100) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    entity VARCHAR(50) NOT NULL,
    data JSONB NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    applied BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_sync_operations_user_id (user_id),
    INDEX idx_sync_operations_timestamp (timestamp),
    INDEX idx_sync_operations_applied (applied)
);

-- Таблица биометрических сессий
CREATE TABLE biometric_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,
    public_key TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_valid BOOLEAN DEFAULT true,

    INDEX idx_biometric_sessions_user_id (user_id),
    INDEX idx_biometric_sessions_expires_at (expires_at),
    UNIQUE(user_id, device_id)
);

-- Таблица пользовательских настроек
CREATE TABLE user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    auto_apply_level INTEGER DEFAULT 1,
    min_match_score DECIMAL(3,2) DEFAULT 0.70,
    daily_apply_limit INTEGER DEFAULT 50,
    preferred_time VARCHAR(5) DEFAULT '08:00',
    notification_prefs JSONB DEFAULT '{}',
    privacy_settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(user_id)
);

-- Функция для обновления времени
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггеры для обновления времени
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_resumes_updated_at BEFORE UPDATE ON resumes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vacancies_updated_at BEFORE UPDATE ON vacancies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_search_configs_updated_at BEFORE UPDATE ON search_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_hh_tokens_updated_at BEFORE UPDATE ON hh_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON user_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Функция для сброса дневных квот
CREATE OR REPLACE FUNCTION reset_daily_quotas()
RETURNS void AS $$
BEGIN
    UPDATE users
    SET used_today = 0,
        reset_at = CURRENT_TIMESTAMP + INTERVAL '1 day'
    WHERE reset_at <= CURRENT_TIMESTAMP;
END;
$$ language 'plpgsql';

-- Создание scheduled job для сброса квот (ежедневно в 00:00)
SELECT cron.schedule('reset-daily-quotas', '0 0 * * *', 'SELECT reset_daily_quotas()');
EOF
)"

    # Миграция вниз
    create_file "$BACKEND_DIR/internal/infrastructure/database/migrations/001_init_schema.down.sql" "$(cat <<'EOF'
-- Удаление scheduled job
SELECT cron.unschedule('reset-daily-quotas');

-- Удаление функций
DROP FUNCTION IF EXISTS reset_daily_quotas();
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Удаление триггеров
DROP TRIGGER IF EXISTS update_user_settings_updated_at ON user_settings;
DROP TRIGGER IF EXISTS update_hh_tokens_updated_at ON hh_tokens;
DROP TRIGGER IF EXISTS update_search_configs_updated_at ON search_configs;
DROP TRIGGER IF EXISTS update_vacancies_updated_at ON vacancies;
DROP TRIGGER IF EXISTS update_resumes_updated_at ON resumes;
DROP TRIGGER IF EXISTS update_users_updated_at ON users;

-- Удаление таблиц в обратном порядке зависимостей
DROP TABLE IF EXISTS biometric_sessions;
DROP TABLE IF EXISTS sync_operations;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS hh_tokens;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS applications;
DROP TABLE IF EXISTS search_configs;
DROP TABLE IF EXISTS vacancies;
DROP TABLE IF EXISTS resumes;
DROP TABLE IF EXISTS users;
EOF
)"

    echo "✅ Миграции базы данных созданы"
    echo ""

    # 2. СОЗДАНИЕ КОДА ДЛЯ РАБОТЫ С БАЗОЙ ДАННЫХ
    echo "2. Создание кода для работы с базой данных..."

    create_go_file "$BACKEND_DIR/internal/infrastructure/database/postgres.go" "database" "$(cat <<'EOF'
package database

import (
    "context"
    "database/sql"
    "fmt"
    "time"

    _ "github.com/lib/pq"
    "github.com/jmoiron/sqlx"
    "autojobsearch/backend/config"
    "autojobsearch/backend/pkg/logger"
)

type Postgres struct {
    db *sqlx.DB
}

func NewPostgres(cfg *config.Config) (*Postgres, error) {
    connStr := fmt.Sprintf(
        "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
        cfg.Database.Host,
        cfg.Database.Port,
        cfg.Database.User,
        cfg.Database.Password,
        cfg.Database.Name,
        cfg.Database.SSLMode,
    )

    db, err := sqlx.Open("postgres", connStr)
    if err != nil {
        return nil, fmt.Errorf("failed to open database: %w", err)
    }

    // Настройка пула соединений
    db.SetMaxOpenConns(cfg.Database.MaxConns)
    db.SetMaxIdleConns(cfg.Database.MaxIdleConns)
    db.SetConnMaxLifetime(cfg.Database.ConnMaxLifetime)

    // Проверка подключения
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := db.PingContext(ctx); err != nil {
        return nil, fmt.Errorf("failed to ping database: %w", err)
    }

    logger.Info("Connected to PostgreSQL database")

    return &Postgres{db: db}, nil
}

func (p *Postgres) GetDB() *sqlx.DB {
    return p.db
}

func (p *Postgres) Close() error {
    return p.db.Close()
}

func (p *Postgres) BeginTx(ctx context.Context) (*sql.Tx, error) {
    return p.db.BeginTx(ctx, nil)
}

func (p *Postgres) HealthCheck(ctx context.Context) error {
    return p.db.PingContext(ctx)
}

// QueryRow выполняет запрос и возвращает одну строку
func (p *Postgres) QueryRow(ctx context.Context, query string, args ...interface{}) *sql.Row {
    return p.db.QueryRowContext(ctx, query, args...)
}

// Query выполняет запрос и возвращает несколько строк
func (p *Postgres) Query(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
    return p.db.QueryContext(ctx, query, args...)
}

// Exec выполняет запрос без возврата строк
func (p *Postgres) Exec(ctx context.Context, query string, args ...interface{}) (sql.Result, error) {
    return p.db.ExecContext(ctx, query, args...)
}

// Get извлекает одну запись в структуру
func (p *Postgres) Get(ctx context.Context, dest interface{}, query string, args ...interface{}) error {
    return p.db.GetContext(ctx, dest, query, args...)
}

// Select извлекает несколько записей в срез структур
func (p *Postgres) Select(ctx context.Context, dest interface{}, query string, args ...interface{}) error {
    return p.db.SelectContext(ctx, dest, query, args...)
}
EOF
)"

    echo "✅ Код для работы с БД создан"
    echo ""

    # 3. СОЗДАНИЕ REDIS КЭША
    echo "3. Создание Redis кэша..."

    create_go_file "$BACKEND_DIR/internal/infrastructure/cache/redis_cache.go" "cache" "$(cat <<'EOF'
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"

    "github.com/go-redis/redis/v8"
    "autojobsearch/backend/config"
    "autojobsearch/backend/pkg/logger"
)

type RedisCache struct {
    client *redis.Client
}

func NewRedisCache(cfg *config.Config) (*RedisCache, error) {
    client := redis.NewClient(&redis.Options{
        Addr:     fmt.Sprintf("%s:%s", cfg.Redis.Host, cfg.Redis.Port),
        Password: cfg.Redis.Password,
        DB:       cfg.Redis.DB,
        PoolSize: 100,
        MinIdleConns: 10,
        DialTimeout:  5 * time.Second,
        ReadTimeout:  3 * time.Second,
        WriteTimeout: 3 * time.Second,
        PoolTimeout:  4 * time.Second,
    })

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := client.Ping(ctx).Err(); err != nil {
        return nil, fmt.Errorf("failed to connect to Redis: %w", err)
    }

    logger.Info("Connected to Redis")

    return &RedisCache{client: client}, nil
}

func (r *RedisCache) Set(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
    jsonData, err := json.Marshal(value)
    if err != nil {
        return fmt.Errorf("failed to marshal value: %w", err)
    }

    return r.client.Set(ctx, key, jsonData, expiration).Err()
}

func (r *RedisCache) Get(ctx context.Context, key string, dest interface{}) error {
    data, err := r.client.Get(ctx, key).Result()
    if err != nil {
        if err == redis.Nil {
            return fmt.Errorf("key not found: %s", key)
        }
        return err
    }

    return json.Unmarshal([]byte(data), dest)
}

func (r *RedisCache) Delete(ctx context.Context, key string) error {
    return r.client.Del(ctx, key).Err()
}

func (r *RedisCache) Exists(ctx context.Context, key string) (bool, error) {
    result, err := r.client.Exists(ctx, key).Result()
    if err != nil {
        return false, err
    }
    return result > 0, nil
}

func (r *RedisCache) Increment(ctx context.Context, key string) (int64, error) {
    return r.client.Incr(ctx, key).Result()
}

func (r *RedisCache) IncrementBy(ctx context.Context, key string, value int64) (int64, error) {
    return r.client.IncrBy(ctx, key, value).Result()
}

func (r *RedisCache) Decrement(ctx context.Context, key string) (int64, error) {
    return r.client.Decr(ctx, key).Result()
}

func (r *RedisCache) Expire(ctx context.Context, key string, expiration time.Duration) error {
    return r.client.Expire(ctx, key, expiration).Err()
}

func (r *RedisCache) TTL(ctx context.Context, key string) (time.Duration, error) {
    return r.client.TTL(ctx, key).Result()
}

func (r *RedisCache) Keys(ctx context.Context, pattern string) ([]string, error) {
    return r.client.Keys(ctx, pattern).Result()
}

func (r *RedisCache) FlushAll(ctx context.Context) error {
    return r.client.FlushAll(ctx).Err()
}

func (r *RedisCache) Close() error {
    return r.client.Close()
}

// SetNX устанавливает значение только если ключ не существует
func (r *RedisCache) SetNX(ctx context.Context, key string, value interface{}, expiration time.Duration) (bool, error) {
    jsonData, err := json.Marshal(value)
    if err != nil {
        return false, fmt.Errorf("failed to marshal value: %w", err)
    }

    return r.client.SetNX(ctx, key, jsonData, expiration).Result()
}

// Pipeline для массовых операций
func (r *RedisCache) Pipeline() redis.Pipeliner {
    return r.client.Pipeline()
}

// Transaction для атомарных операций
func (r *RedisCache) Transaction(ctx context.Context, fn func(tx *redis.Tx) error) error {
    return r.client.Watch(ctx, fn)
}
EOF
)"

    echo "✅ Redis кэш создан"
    echo ""

    # 4. СОЗДАНИЕ ОЧЕРЕДЕЙ RABBITMQ
    echo "4. Создание очередей RabbitMQ..."

    create_go_file "$BACKEND_DIR/internal/infrastructure/queue/rabbitmq.go" "queue" "$(cat <<'EOF'
package queue

import (
    "context"
    "encoding/json"
    "fmt"
    "time"

    amqp "github.com/rabbitmq/amqp091-go"
    "autojobsearch/backend/config"
    "autojobsearch/backend/pkg/logger"
)

type RabbitMQ struct {
    conn    *amqp.Connection
    channel *amqp.Channel
    config  *config.Config
}

type QueueMessage struct {
    ID        string      `json:"id"`
    Type      string      `json:"type"`
    UserID    string      `json:"user_id"`
    Data      interface{} `json:"data"`
    Timestamp time.Time   `json:"timestamp"`
    RetryCount int        `json:"retry_count"`
}

func NewRabbitMQ(cfg *config.Config) (*RabbitMQ, error) {
    conn, err := amqp.Dial(cfg.RabbitMQ.URL)
    if err != nil {
        return nil, fmt.Errorf("failed to connect to RabbitMQ: %w", err)
    }

    channel, err := conn.Channel()
    if err != nil {
        conn.Close()
        return nil, fmt.Errorf("failed to open channel: %w", err)
    }

    // Объявление exchange
    err = channel.ExchangeDeclare(
        cfg.RabbitMQ.Exchange, // name
        "direct",              // type
        true,                  // durable
        false,                 // auto-deleted
        false,                 // internal
        false,                 // no-wait
        nil,                   // arguments
    )
    if err != nil {
        channel.Close()
        conn.Close()
        return nil, fmt.Errorf("failed to declare exchange: %w", err)
    }

    // Объявление очередей
    queues := []string{
        "search_jobs",
        "auto_apply_jobs",
        "notification_jobs",
        "sync_jobs",
        "dead_letter",
    }

    for _, queue := range queues {
        _, err = channel.QueueDeclare(
            queue, // name
            true,  // durable
            false, // delete when unused
            false, // exclusive
            false, // no-wait
            amqp.Table{
                "x-dead-letter-exchange":    "",
                "x-dead-letter-routing-key": "dead_letter",
            },
        )
        if err != nil {
            channel.Close()
            conn.Close()
            return nil, fmt.Errorf("failed to declare queue %s: %w", queue, err)
        }

        // Привязка очереди к exchange
        err = channel.QueueBind(
            queue,                    // queue name
            queue,                    // routing key
            cfg.RabbitMQ.Exchange,    // exchange
            false,                    // no-wait
            nil,                      // arguments
        )
        if err != nil {
            channel.Close()
            conn.Close()
            return nil, fmt.Errorf("failed to bind queue %s: %w", queue, err)
        }
    }

    logger.Info("Connected to RabbitMQ")

    return &RabbitMQ{
        conn:    conn,
        channel: channel,
        config:  cfg,
    }, nil
}

func (r *RabbitMQ) Publish(ctx context.Context, queue string, message QueueMessage) error {
    message.ID = generateMessageID()
    message.Timestamp = time.Now()

    body, err := json.Marshal(message)
    if err != nil {
        return fmt.Errorf("failed to marshal message: %w", err)
    }

    err = r.channel.PublishWithContext(
        ctx,
        r.config.RabbitMQ.Exchange, // exchange
        queue,                      // routing key
        false,                      // mandatory
        false,                      // immediate
        amqp.Publishing{
            ContentType:  "application/json",
            Body:         body,
            DeliveryMode: amqp.Persistent,
            Timestamp:    time.Now(),
        },
    )

    if err != nil {
        return fmt.Errorf("failed to publish message: %w", err)
    }

    logger.Debug("Message published to queue",
        zap.String("queue", queue),
        zap.String("message_id", message.ID),
        zap.String("type", message.Type),
    )

    return nil
}

func (r *RabbitMQ) Consume(queue string, handler func(message QueueMessage) error) error {
    msgs, err := r.channel.Consume(
        queue,    // queue
        "",       // consumer
        false,    // auto-ack
        false,    // exclusive
        false,    // no-local
        false,    // no-wait
        nil,      // args
    )
    if err != nil {
        return fmt.Errorf("failed to consume from queue %s: %w", queue, err)
    }

    go func() {
        for msg := range msgs {
            var message QueueMessage
            if err := json.Unmarshal(msg.Body, &message); err != nil {
                logger.Error("Failed to unmarshal message", zap.Error(err))
                msg.Nack(false, false) // Не переотправлять
                continue
            }

            // Обработка сообщения
            if err := handler(message); err != nil {
                logger.Error("Failed to process message",
                    zap.Error(err),
                    zap.String("message_id", message.ID),
                )

                // Если превышено количество попыток - в dead letter
                if message.RetryCount >= 3 {
                    logger.Warn("Message moved to dead letter",
                        zap.String("message_id", message.ID),
                        zap.Int("retry_count", message.RetryCount),
                    )
                    msg.Nack(false, false)
                } else {
                    // Повторная отправка с задержкой
                    message.RetryCount++
                    time.Sleep(time.Duration(message.RetryCount) * time.Second)
                    msg.Nack(false, true)
                }
            } else {
                // Успешная обработка
                msg.Ack(false)
                logger.Debug("Message processed successfully",
                    zap.String("message_id", message.ID),
                )
            }
        }
    }()

    return nil
}

func (r *RabbitMQ) Close() error {
    if err := r.channel.Close(); err != nil {
        return err
    }
    return r.conn.Close()
}

func (r *RabbitMQ) HealthCheck(ctx context.Context) error {
    // Проверка соединения
    if r.conn.IsClosed() {
        return fmt.Errorf("rabbitmq connection is closed")
    }

    // Проверка канала
    if r.channel.IsClosed() {
        return fmt.Errorf("rabbitmq channel is closed")
    }

    return nil
}

func generateMessageID() string {
    return fmt.Sprintf("msg_%d", time.Now().UnixNano())
}
EOF
)"

    echo "✅ Очереди RabbitMQ созданы"
    echo ""

    # 5. СОЗДАНИЕ ШИФРОВАНИЯ E2E
    echo "5. Создание E2E шифрования..."

    create_go_file "$BACKEND_DIR/internal/infrastructure/encryption/e2e_encryption.go" "encryption" "$(cat <<'EOF'
package encryption

import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"
    "crypto/rsa"
    "crypto/sha256"
    "crypto/x509"
    "encoding/base64"
    "encoding/pem"
    "errors"
    "fmt"
    "io"

    "autojobsearch/backend/config"
    "autojobsearch/backend/pkg/logger"
)

type E2EEncryption struct {
    config *config.Config
}

type EncryptedPayload struct {
    EncryptedKey  string `json:"encrypted_key"`
    EncryptedData string `json:"encrypted_data"`
    Nonce         string `json:"nonce"`
    Signature     string `json:"signature,omitempty"`
    Timestamp     int64  `json:"timestamp"`
    Version       string `json:"version"`
}

func NewE2EEncryption(cfg *config.Config) *E2EEncryption {
    return &E2EEncryption{
        config: cfg,
    }
}

// EncryptData шифрует данные с использованием гибридного шифрования
func (e *E2EEncryption) EncryptData(data []byte, userPublicKeyPEM string) (*EncryptedPayload, error) {
    // 1. Генерация сессионного ключа AES
    sessionKey := make([]byte, 32) // 256 бит для AES-256
    if _, err := io.ReadFull(rand.Reader, sessionKey); err != nil {
        return nil, fmt.Errorf("failed to generate session key: %w", err)
    }

    // 2. Шифрование данных AES-GCM
    encryptedData, nonce, err := e.aesGCMEncrypt(sessionKey, data)
    if err != nil {
        return nil, fmt.Errorf("failed to encrypt data: %w", err)
    }

    // 3. Загрузка публичного ключа пользователя
    userPublicKey, err := e.loadPublicKey(userPublicKeyPEM)
    if err != nil {
        return nil, fmt.Errorf("failed to load public key: %w", err)
    }

    // 4. Шифрование сессионного ключа RSA-OAEP
    encryptedKey, err := rsa.EncryptOAEP(
        sha256.New(),
        rand.Reader,
        userPublicKey,
        sessionKey,
        nil,
    )
    if err != nil {
        return nil, fmt.Errorf("failed to encrypt session key: %w", err)
    }

    // 5. Создание подписи (опционально)
    signature, err := e.createSignature(encryptedData, userPublicKey)
    if err != nil {
        logger.Warn("Failed to create signature, continuing without it", zap.Error(err))
    }

    return &EncryptedPayload{
        EncryptedKey:  base64.StdEncoding.EncodeToString(encryptedKey),
        EncryptedData: base64.StdEncoding.EncodeToString(encryptedData),
        Nonce:         base64.StdEncoding.EncodeToString(nonce),
        Signature:     base64.StdEncoding.EncodeToString(signature),
        Timestamp:     time.Now().Unix(),
        Version:       "1.0",
    }, nil
}

// DecryptData расшифровывает данные с использованием приватного ключа пользователя
func (e *E2EEncryption) DecryptData(payload *EncryptedPayload, userPrivateKeyPEM string) ([]byte, error) {
    // 1. Декодирование зашифрованного ключа
    encryptedKey, err := base64.StdEncoding.DecodeString(payload.EncryptedKey)
    if err != nil {
        return nil, fmt.Errorf("failed to decode encrypted key: %w", err)
    }

    // 2. Загрузка приватного ключа пользователя
    userPrivateKey, err := e.loadPrivateKey(userPrivateKeyPEM)
    if err != nil {
        return nil, fmt.Errorf("failed to load private key: %w", err)
    }

    // 3. Расшифровка сессионного ключа
    sessionKey, err := rsa.DecryptOAEP(
        sha256.New(),
        rand.Reader,
        userPrivateKey,
        encryptedKey,
        nil,
    )
    if err != nil {
        return nil, fmt.Errorf("failed to decrypt session key: %w", err)
    }

    // 4. Декодирование данных и nonce
    encryptedData, err := base64.StdEncoding.DecodeString(payload.EncryptedData)
    if err != nil {
        return nil, fmt.Errorf("failed to decode encrypted data: %w", err)
    }

    nonce, err := base64.StdEncoding.DecodeString(payload.Nonce)
    if err != nil {
        return nil, fmt.Errorf("failed to decode nonce: %w", err)
    }

    // 5. Проверка подписи (если есть)
    if payload.Signature != "" {
        signature, err := base64.StdEncoding.DecodeString(payload.Signature)
        if err != nil {
            return nil, fmt.Errorf("failed to decode signature: %w", err)
        }

        if err := e.verifySignature(encryptedData, signature, &userPrivateKey.PublicKey); err != nil {
            return nil, fmt.Errorf("signature verification failed: %w", err)
        }
    }

    // 6. Расшифровка данных
    decryptedData, err := e.aesGCMDecrypt(sessionKey, encryptedData, nonce)
    if err != nil {
        return nil, fmt.Errorf("failed to decrypt data: %w", err)
    }

    return decryptedData, nil
}

// GenerateKeyPair генерирует новую пару RSA ключей
func (e *E2EEncryption) GenerateKeyPair() (privateKeyPEM, publicKeyPEM string, err error) {
    // Генерация ключа
    privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
    if err != nil {
        return "", "", fmt.Errorf("failed to generate RSA key pair: %w", err)
    }

    // Кодирование приватного ключа в PEM
    privateKeyBytes := x509.MarshalPKCS1PrivateKey(privateKey)
    privateKeyPEM = string(pem.EncodeToMemory(&pem.Block{
        Type:  "RSA PRIVATE KEY",
        Bytes: privateKeyBytes,
    }))

    // Кодирование публичного ключа в PEM
    publicKeyBytes, err := x509.MarshalPKIXPublicKey(&privateKey.PublicKey)
    if err != nil {
        return "", "", fmt.Errorf("failed to marshal public key: %w", err)
    }

    publicKeyPEM = string(pem.EncodeToMemory(&pem.Block{
        Type:  "PUBLIC KEY",
        Bytes: publicKeyBytes,
    }))

    return privateKeyPEM, publicKeyPEM, nil
}

// aesGCMEncrypt шифрует данные с использованием AES-GCM
func (e *E2EEncryption) aesGCMEncrypt(key, data []byte) ([]byte, []byte, error) {
    block, err := aes.NewCipher(key)
    if err != nil {
        return nil, nil, err
    }

    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, nil, err
    }

    nonce := make([]byte, gcm.NonceSize())
    if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
        return nil, nil, err
    }

    ciphertext := gcm.Seal(nonce, nonce, data, nil)
    return ciphertext[gcm.NonceSize():], nonce, nil
}

// aesGCMDecrypt расшифровывает данные с использованием AES-GCM
func (e *E2EEncryption) aesGCMDecrypt(key, ciphertext, nonce []byte) ([]byte, error) {
    block, err := aes.NewCipher(key)
    if err != nil {
        return nil, err
    }

    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, err
    }

    return gcm.Open(nil, nonce, ciphertext, nil)
}

// loadPublicKey загружает публичный ключ из PEM
func (e *E2EEncryption) loadPublicKey(publicKeyPEM string) (*rsa.PublicKey, error) {
    block, _ := pem.Decode([]byte(publicKeyPEM))
    if block == nil {
        return nil, errors.New("failed to parse PEM block containing public key")
    }

    pub, err := x509.ParsePKIXPublicKey(block.Bytes)
    if err != nil {
        return nil, err
    }

    publicKey, ok := pub.(*rsa.PublicKey)
    if !ok {
        return nil, errors.New("not an RSA public key")
    }

    return publicKey, nil
}

// loadPrivateKey загружает приватный ключ из PEM
func (e *E2EEncryption) loadPrivateKey(privateKeyPEM string) (*rsa.PrivateKey, error) {
    block, _ := pem.Decode([]byte(privateKeyPEM))
    if block == nil {
        return nil, errors.New("failed to parse PEM block containing private key")
    }

    privateKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
    if err != nil {
        return nil, err
    }

    return privateKey, nil
}

// createSignature создает подпись для данных
func (e *E2EEncryption) createSignature(data []byte, privateKey *rsa.PrivateKey) ([]byte, error) {
    hashed := sha256.Sum256(data)
    return rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, hashed[:])
}

// verifySignature проверяет подпись
func (e *E2EEncryption) verifySignature(data, signature []byte, publicKey *rsa.PublicKey) error {
    hashed := sha256.Sum256(data)
    return rsa.VerifyPKCS1v15(publicKey, crypto.SHA256, hashed[:], signature)
}

// GenerateBiometricKey генерирует ключ для биометрической аутентификации
func (e *E2EEncryption) GenerateBiometricKey() (string, error) {
    key := make([]byte, 32)
    if _, err := io.ReadFull(rand.Reader, key); err != nil {
        return "", err
    }

    // Дополнительное хеширование для безопасности
    hashed := sha256.Sum256(key)
    return base64.StdEncoding.EncodeToString(hashed[:]), nil
}
EOF
)"

    echo "✅ E2E шифрование создано"
    echo ""

    # 6. СОЗДАНИЕ ML ИНФРАСТРУКТУРЫ
    echo "6. Создание ML инфраструктуры..."

    create_go_file "$BACKEND_DIR/internal/infrastructure/ml/models.go" "ml" "$(cat <<'EOF'
package ml

import (
    "context"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "sync"
    "time"

    "github.com/tensorflow/tensorflow/tensorflow/go"
    "github.com/tensorflow/tensorflow/tensorflow/go/op"
    "autojobsearch/backend/config"
    "autojobsearch/backend/pkg/logger"
)

type ModelType string

const (
    ModelTypeSkills   ModelType = "skills"
    ModelTypeSalary   ModelType = "salary"
    ModelTypeGenerator ModelType = "generator"
)

type MLModel struct {
    Type        ModelType
    Model       *tensorflow.SavedModel
    Version     string
    LoadedAt    time.Time
    IsQuantized bool
    InputShape  []int64
    OutputShape []int64
}

type MLManager struct {
    models      map[ModelType]*MLModel
    modelPath   string
    cacheSize   int
    mu          sync.RWMutex
    config      *config.Config
}

type GenerationConfig struct {
    MaxTokens      int
    Temperature    float64
    TopP           float64
    StopSequences  []string
    RepetitionPenalty float64
}

type PredictionResult struct {
    Value       float64
    Confidence  float64
    Features    map[string]interface{}
    Timestamp   time.Time
}

func NewMLManager(cfg *config.Config) (*MLManager, error) {
    // Создание директории для моделей, если не существует
    if err := os.MkdirAll(cfg.ML.ModelPath, 0755); err != nil {
        return nil, fmt.Errorf("failed to create model directory: %w", err)
    }

    manager := &MLManager{
        models:    make(map[ModelType]*MLModel),
        modelPath: cfg.ML.ModelPath,
        cacheSize: cfg.ML.CacheSize,
        config:    cfg,
    }

    // Предзагрузка моделей
    if err := manager.preloadModels(); err != nil {
        logger.Warn("Failed to preload some models", zap.Error(err))
    }

    return manager, nil
}

// LoadModel загружает модель из файла
func (m *MLManager) LoadModel(modelType ModelType, modelPath string) (*MLModel, error) {
    m.mu.Lock()
    defer m.mu.Unlock()

    // Проверка кэша
    if model, exists := m.models[modelType]; exists {
        if time.Since(model.LoadedAt) < 24*time.Hour {
            return model, nil
        }
        // Модель устарела, перезагружаем
        delete(m.models, modelType)
    }

    // Загрузка модели TensorFlow
    model, err := tensorflow.LoadSavedModel(modelPath, []string{"serve"}, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to load model %s: %w", modelType, err)
    }

    mlModel := &MLModel{
        Type:     modelType,
        Model:    model,
        Version:  getModelVersion(modelPath),
        LoadedAt: time.Now(),
    }

    // Определение характеристик модели
    m.analyzeModel(mlModel)

    // Сохранение в кэш
    m.models[modelType] = mlModel

    // Очистка кэша если превышен лимит
    m.cleanupCache()

    logger.Info("Model loaded successfully",
        zap.String("type", string(modelType)),
        zap.String("version", mlModel.Version),
        zap.Time("loaded_at", mlModel.LoadedAt),
    )

    return mlModel, nil
}

// PredictSkills предсказывает соответствие навыков
func (m *MLManager) PredictSkills(ctx context.Context, resumeFeatures, vacancyFeatures map[string]interface{}) (*PredictionResult, error) {
    model, err := m.getModel(ModelTypeSkills)
    if err != nil {
        return nil, err
    }

    // Подготовка входных данных
    inputTensor, err := m.prepareSkillsInput(resumeFeatures, vacancyFeatures)
    if err != nil {
        return nil, fmt.Errorf("failed to prepare input: %w", err)
    }

    // Выполнение предсказания
    output, err := model.Model.Session.Run(
        map[tensorflow.Output]*tensorflow.Tensor{
            model.Model.Graph.Operation("input").Output(0): inputTensor,
        },
        []tensorflow.Output{
            model.Model.Graph.Operation("output").Output(0),
        },
        nil,
    )
    if err != nil {
        return nil, fmt.Errorf("prediction failed: %w", err)
    }

    if len(output) == 0 {
        return nil, fmt.Errorf("no output from model")
    }

    value := output[0].Value().(float32)

    return &PredictionResult{
        Value:      float64(value),
        Confidence: m.calculateConfidence(value),
        Features:   m.mergeFeatures(resumeFeatures, vacancyFeatures),
        Timestamp:  time.Now(),
    }, nil
}

// PredictSalary предсказывает зарплату
func (m *MLManager) PredictSalary(ctx context.Context, features map[string]interface{}) (*PredictionResult, error) {
    model, err := m.getModel(ModelTypeSalary)
    if err != nil {
        return nil, err
    }

    inputTensor, err := m.prepareSalaryInput(features)
    if err != nil {
        return nil, err
    }

    output, err := model.Model.Session.Run(
        map[tensorflow.Output]*tensorflow.Tensor{
            model.Model.Graph.Operation("features").Output(0): inputTensor,
        },
        []tensorflow.Output{
            model.Model.Graph.Operation("salary_prediction").Output(0),
            model.Model.Graph.Operation("confidence").Output(0),
        },
        nil,
    )
    if err != nil {
        return nil, err
    }

    if len(output) < 2 {
        return nil, fmt.Errorf("invalid output from salary model")
    }

    salary := output[0].Value().(float32)
    confidence := output[1].Value().(float32)

    return &PredictionResult{
        Value:      float64(salary),
        Confidence: float64(confidence),
        Features:   features,
        Timestamp:  time.Now(),
    }, nil
}

// GenerateText генерирует текст с помощью модели
func (m *MLManager) GenerateText(ctx context.Context, prompt string, config GenerationConfig) (string, error) {
    model, err := m.getModel(ModelTypeGenerator)
    if err != nil {
        return "", err
    }

    // Токенизация промпта
    tokens, err := m.tokenizeText(prompt)
    if err != nil {
        return "", err
    }

    // Подготовка входных данных
    inputTensor, err := tensorflow.NewTensor(tokens)
    if err != nil {
        return "", err
    }

    // Параметры генерации
    generationParams := map[string]interface{}{
        "max_length":      config.MaxTokens,
        "temperature":     config.Temperature,
        "top_p":           config.TopP,
        "repetition_penalty": config.RepetitionPenalty,
    }

    // Выполнение генерации
    outputs, err := model.Model.Session.Run(
        map[tensorflow.Output]*tensorflow.Tensor{
            model.Model.Graph.Operation("input_ids").Output(0): inputTensor,
            model.Model.Graph.Operation("generation_params").Output(0): m.createParamsTensor(generationParams),
        },
        []tensorflow.Output{
            model.Model.Graph.Operation("generated_text").Output(0),
        },
        nil,
    )
    if err != nil {
        return "", err
    }

    generatedTokens := outputs[0].Value().([]int32)

    // Детокенизация
    generatedText, err := m.detokenizeText(generatedTokens)
    if err != nil {
        return "", err
    }

    // Обрезка по стоп-последовательностям
    generatedText = m.trimStopSequences(generatedText, config.StopSequences)

    return generatedText, nil
}

// getModel получает модель из кэша или загружает ее
func (m *MLManager) getModel(modelType ModelType) (*MLModel, error) {
    m.mu.RLock()
    model, exists := m.models[modelType]
    m.mu.RUnlock()

    if exists && time.Since(model.LoadedAt) < 24*time.Hour {
        return model, nil
    }

    // Загрузка модели
    modelPath := filepath.Join(m.modelPath, string(modelType))
    return m.LoadModel(modelType, modelPath)
}

// preloadModels предзагружает часто используемые модели
func (m *MLManager) preloadModels() error {
    modelsToPreload := []ModelType{
        ModelTypeSkills,
        ModelTypeSalary,
    }

    for _, modelType := range modelsToPreload {
        modelPath := filepath.Join(m.modelPath, string(modelType))
        if _, err := os.Stat(modelPath); err == nil {
            if _, err := m.LoadModel(modelType, modelPath); err != nil {
                logger.Error("Failed to preload model",
                    zap.String("type", string(modelType)),
                    zap.Error(err),
                )
            }
        }
    }

    return nil
}

// cleanupCache очищает кэш моделей
func (m *MLManager) cleanupCache() {
    if len(m.models) <= m.cacheSize {
        return
    }

    // Находим самую старую модель
    var oldestModel ModelType
    var oldestTime time.Time

    for modelType, model := range m.models {
        if oldestTime.IsZero() || model.LoadedAt.Before(oldestTime) {
            oldestTime = model.LoadedAt
            oldestModel = modelType
        }
    }

    // Удаляем самую старую модель
    if oldestModel != "" {
        delete(m.models, oldestModel)
        logger.Debug("Model removed from cache",
            zap.String("type", string(oldestModel)),
            zap.Time("loaded_at", oldestTime),
        )
    }
}

// analyzeModel анализирует характеристики модели
func (m *MLManager) analyzeModel(model *MLModel) {
    // Анализ графа модели для определения входов/выходов
    // В реальной реализации здесь будет анализ TensorFlow графа
    model.InputShape = []int64{1, 256}  // Пример
    model.OutputShape = []int64{1, 1}   // Пример
    model.IsQuantized = m.checkIfQuantized(model.Model.Graph)
}

// Вспомогательные методы
func (m *MLManager) prepareSkillsInput(resumeFeatures, vacancyFeatures map[string]interface{}) (*tensorflow.Tensor, error) {
    // Преобразование features в tensor
    combinedFeatures := m.combineFeatures(resumeFeatures, vacancyFeatures)
    return tensorflow.NewTensor(combinedFeatures)
}

func (m *MLManager) prepareSalaryInput(features map[string]interface{}) (*tensorflow.Tensor, error) {
    // Нормализация features для модели зарплат
    normalizedFeatures := m.normalizeSalaryFeatures(features)
    return tensorflow.NewTensor(normalizedFeatures)
}

func (m *MLManager) tokenizeText(text string) ([]int32, error) {
    // Простая токенизация (в реальной системе будет BPE или WordPiece)
    // Здесь заглушка
    tokens := make([]int32, 0)
    for _, char := range text {
        tokens = append(tokens, int32(char))
    }
    return tokens, nil
}

func (m *MLManager) detokenizeText(tokens []int32) (string, error) {
    // Простая детокенизация
    runes := make([]rune, len(tokens))
    for i, token := range tokens {
        runes[i] = rune(token)
    }
    return string(runes), nil
}

func (m *MLManager) trimStopSequences(text string, stopSequences []string) string {
    for _, seq := range stopSequences {
        if idx := indexOf(text, seq); idx != -1 {
            text = text[:idx]
        }
    }
    return text
}

func (m *MLManager) createParamsTensor(params map[string]interface{}) *tensorflow.Tensor {
    // Создание тензора с параметрами
    jsonData, _ := json.Marshal(params)
    tensor, _ := tensorflow.NewTensor(string(jsonData))
    return tensor
}

func (m *MLManager) checkIfQuantized(graph *tensorflow.Graph) bool {
    // Проверка, квантована ли модель
    // В реальной системе здесь будет проверка операций графа
    return false
}

func getModelVersion(modelPath string) string {
    // Чтение версии модели из файла
    versionFile := filepath.Join(modelPath, "version.txt")
    if data, err := os.ReadFile(versionFile); err == nil {
        return string(data)
    }
    return "1.0.0"
}

func indexOf(str, substr string) int {
    for i := 0; i <= len(str)-len(substr); i++ {
        if str[i:i+len(substr)] == substr {
            return i
        }
    }
    return -1
}
EOF
)"

    echo "✅ ML инфраструктура создана"
    echo ""

    # 7. СОЗДАНИЕ СКРИПТОВ АДМИНИСТРИРОВАНИЯ
    echo "7. Создание скриптов администрирования..."

    create_file "$BACKEND_DIR/scripts/migrate.sh" "$(cat <<'EOF'
#!/bin/bash

# Скрипт для выполнения миграций базы данных
# Использование: ./scripts/migrate.sh [up|down|redo|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATIONS_DIR="$PROJECT_ROOT/internal/infrastructure/database/migrations"

# Загрузка переменных окружения
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    export $(cat "$PROJECT_ROOT/.env" | grep -v '^#' | xargs)
else
    echo "Warning: .env file not found, using defaults"
fi

# Проверка goose
if ! command -v goose &> /dev/null; then
    echo "Installing goose..."
    go install github.com/pressly/goose/v3/cmd/goose@latest
fi

# Настройка подключения к БД
DB_CONN_STRING="postgres://${DB_USER:-postgres}:${DB_PASSWORD:-postgres}@${DB_HOST:-localhost}:${DB_PORT:-5432}/${DB_NAME:-autojobsearch}?sslmode=${DB_SSLMODE:-disable}"

# Функция для вывода помощи
show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  up        Apply all pending migrations"
    echo "  down      Rollback the last migration"
    echo "  redo      Rollback and re-apply the last migration"
    echo "  status    Show migration status"
    echo "  create    Create a new migration file"
    echo "  reset     Reset database (drop and recreate)"
    echo "  seed      Seed database with test data"
    echo ""
    echo "Examples:"
    echo "  $0 up"
    echo "  $0 status"
    echo "  $0 create add_user_settings"
}

# Проверка подключения к БД
check_db_connection() {
    echo "Checking database connection..."

    if ! goose -dir "$MIGRATIONS_DIR" postgres "$DB_CONN_STRING" status > /dev/null 2>&1; then
        echo "Error: Cannot connect to database"
        echo "Connection string: $DB_CONN_STRING"
        exit 1
    fi

    echo "✓ Database connection successful"
}

# Команда up
cmd_up() {
    echo "Applying migrations..."
    goose -dir "$MIGRATIONS_DIR" postgres "$DB_CONN_STRING" up
    echo "✓ Migrations applied successfully"
}

# Команда down
cmd_down() {
    echo "Rolling back last migration..."
    goose -dir "$MIGRATIONS_DIR" postgres "$DB_CONN_STRING" down
    echo "✓ Migration rolled back"
}

# Команда redo
cmd_redo() {
    echo "Redoing last migration..."
    goose -dir "$MIGRATIONS_DIR" postgres "$DB_CONN_STRING" redo
    echo "✓ Migration redone"
}

# Команда status
cmd_status() {
    echo "Migration status:"
    goose -dir "$MIGRATIONS_DIR" postgres "$DB_CONN_STRING" status
}

# Команда create
cmd_create() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Error: Migration name is required"
        echo "Usage: $0 create <migration_name>"
        exit 1
    fi

    echo "Creating migration: $name"
    goose -dir "$MIGRATIONS_DIR" create "$name" sql
    echo "✓ Migration file created"
}

# Команда reset
cmd_reset() {
    read -p "⚠️  WARNING: This will DROP ALL TABLES. Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi

    echo "Resetting database..."

    # Отключение всех подключений
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "postgres" -c "SELECT pg_terminate_backend(pg_stat_activity.pid)
                         FROM pg_stat_activity
                         WHERE pg_stat_activity.datname = '$DB_NAME'
                         AND pid <> pg_backend_pid();" > /dev/null 2>&1 || true

    # Удаление и создание базы данных
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "postgres" -c "DROP DATABASE IF EXISTS $DB_NAME;" > /dev/null 2>&1
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "postgres" -c "CREATE DATABASE $DB_NAME;" > /dev/null 2>&1

    # Применение миграций
    cmd_up

    echo "✓ Database reset successfully"
}

# Команда seed
cmd_seed() {
    echo "Seeding database..."

    # Создание тестовых данных
    SEED_FILE="$PROJECT_ROOT/scripts/seed_data.sql"

    if [[ -f "$SEED_FILE" ]]; then
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
            -d "$DB_NAME" -f "$SEED_FILE" > /dev/null 2>&1
        echo "✓ Test data seeded"
    else
        echo "No seed file found at $SEED_FILE"
        echo "Creating template seed file..."

        cat > "$SEED_FILE" << 'SEEDSQL'
-- AutoJobSearch Seed Data
-- WARNING: This is for development only!

-- Тестовый пользователь
INSERT INTO users (id, email, phone, encryption_key, device_id, is_verified)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'test@autojobsearch.com',
    '+79990001122',
    'test-encryption-key',
    'test-device-123',
    true
)
ON CONFLICT (email) DO NOTHING;

-- Пример резюме
INSERT INTO resumes (id, user_id, title, parsed_data, source_type, is_active)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'Senior Backend Developer',
    '{
        "personal_info": {
            "full_name": "Иван Иванов",
            "email": "test@autojobsearch.com",
            "phone": "+79990001122"
        },
        "work_experience": [
            {
                "company": "TechCorp",
                "position": "Backend Developer",
                "start_date": "2020-01-01T00:00:00Z",
                "is_current": true,
                "technologies": ["Go", "PostgreSQL", "Redis"]
            }
        ],
        "skills": [
            {"name": "Go", "category": "programming", "level": "expert", "years": 5},
            {"name": "PostgreSQL", "category": "database", "level": "advanced", "years": 4}
        ]
    }',
    'form',
    true
)
ON CONFLICT (id) DO NOTHING;

-- Настройки поиска
INSERT INTO search_configs (id, user_id, name, config, is_active)
VALUES (
    '33333333-3333-3333-3333-333333333333',
    '11111111-1111-1111-1111-111111111111',
    'Default Search',
    '{
        "query": "Go разработчик",
        "region": "Москва",
        "experience": "between3And6",
        "salary_min": 200000
    }',
    true
)
ON CONFLICT (id) DO NOTHING;

-- Пользовательские настройки
INSERT INTO user_settings (id, user_id, auto_apply_level, min_match_score)
VALUES (
    '44444444-4444-4444-4444-444444444444',
    '11111111-1111-1111-1111-111111111111',
    1,
    0.70
)
ON CONFLICT (user_id) DO NOTHING;

SELECT 'Seed data inserted successfully' as status;
SEEDSQL

        echo "✓ Template seed file created at $SEED_FILE"
        echo "Please edit it and run again"
    fi
}

# Основная логика
main() {
    local command="${1:-up}"

    check_db_connection

    case "$command" in
        up)
            cmd_up
            ;;
        down)
            cmd_down
            ;;
        redo)
            cmd_redo
            ;;
        status)
            cmd_status
            ;;
        create)
            cmd_create "$2"
            ;;
        reset)
            cmd_reset
            ;;
        seed)
            cmd_seed
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
EOF
)"

    chmod +x "$BACKEND_DIR/scripts/migrate.sh"

    create_file "$BACKEND_DIR/scripts/deploy.sh" "$(cat <<'EOF'
#!/bin/bash

# Скрипт для развертывания AutoJobSearch Backend
# Использование: ./scripts/deploy.sh [environment]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
log() {
    local level="$1"
    local message="$2"
    local color="$BLUE"

    case "$level" in
        INFO) color="$BLUE" ;;
        SUCCESS) color="$GREEN" ;;
        WARNING) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
    esac

    echo -e "${color}[$level]${NC} $message"
}

# Проверка зависимостей
check_dependencies() {
    log "INFO" "Проверка зависимостей..."

    local missing_deps=()

    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    # Проверка Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        missing_deps+=("docker-compose")
    fi

    # Проверка Go
    if ! command -v go &> /dev/null; then
        missing_deps+=("go")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Отсутствуют зависимости: ${missing_deps[*]}"
        exit 1
    fi

    log "SUCCESS" "Все зависимости установлены"
}

# Сборка приложения
build_application() {
    local env="$1"

    log "INFO" "Сборка приложения для окружения: $env"

    cd "$PROJECT_ROOT"

    # Сборка Go приложения
    log "INFO" "Компиляция Go приложения..."
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/api ./cmd/api

    # Сборка Docker образа
    log "INFO" "Сборка Docker образа..."
    docker build -t autojobsearch/backend:latest -t autojobsearch/backend:$env .

    log "SUCCESS" "Приложение собрано"
}

# Развертывание в Docker
deploy_docker() {
    local env="$1"

    log "INFO" "Развертывание в Docker..."

    cd "$PROJECT_ROOT"

    # Остановка текущих контейнеров
    log "INFO" "Остановка текущих контейнеров..."
    docker-compose -f docker-compose.production.yml down || true

    # Запуск контейнеров
    log "INFO" "Запуск контейнеров..."
    ENV=$env docker-compose -f docker-compose.production.yml up -d

    # Ожидание запуска
    log "INFO" "Ожидание запуска сервисов..."
    sleep 10

    # Проверка здоровья
    log "INFO" "Проверка здоровья сервисов..."

    if curl -s http://localhost:8080/health | grep -q "ok"; then
        log "SUCCESS" "Backend сервис запущен"
    else
        log "ERROR" "Backend сервис не отвечает"
        exit 1
    fi

    if curl -s http://localhost:3000 | grep -q "Grafana"; then
        log "SUCCESS" "Grafana запущена"
    else
        log "WARNING" "Grafana не отвечает"
    fi

    log "SUCCESS" "Развертывание завершено"
}

# Развертывание в Kubernetes
deploy_kubernetes() {
    local env="$1"

    log "INFO" "Развертывание в Kubernetes..."

    # Проверка kubectl
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl не установлен"
        exit 1
    fi

    # Применение манифестов
    cd "$PROJECT_ROOT/k8s"

    # Создание namespace если не существует
    if ! kubectl get namespace autojobsearch-$env &> /dev/null; then
        kubectl create namespace autojobsearch-$env
    fi

    # Применение конфигураций
    kubectl apply -f namespace.yaml
    kubectl apply -f configmap-$env.yaml
    kubectl apply -f secret-$env.yaml
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
    kubectl apply -f ingress.yaml

    # Ожидание развертывания
    log "INFO" "Ожидание готовности pods..."
    kubectl rollout status deployment/autojobsearch-backend -n autojobsearch-$env --timeout=300s

    log "SUCCESS" "Развертывание в Kubernetes завершено"
}

# Миграции базы данных
run_migrations() {
    local env="$1"

    log "INFO" "Запуск миграций базы данных..."

    cd "$PROJECT_ROOT"

    # Запуск миграций
    ./scripts/migrate.sh up

    log "SUCCESS" "Миграции выполнены"
}

# Основная функция
main() {
    local environment="${1:-development}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  AutoJobSearch Backend Deployment      ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Проверка допустимости окружения
    case "$environment" in
        development|staging|production)
            log "INFO" "Развертывание в окружении: $environment"
            ;;
        *)
            log "ERROR" "Неизвестное окружение: $environment"
            echo "Допустимые значения: development, staging, production"
            exit 1
            ;;
    esac

    # Выполнение шагов развертывания
    check_dependencies
    build_application "$environment"
    run_migrations "$environment"

    case "$environment" in
        development|staging)
            deploy_docker "$environment"
            ;;
        production)
            read -p "⚠️  Развертывание в PRODUCTION. Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "INFO" "Развертывание отменено"
                exit 0
            fi
            deploy_kubernetes "$environment"
            ;;
    esac

    # Финальный вывод
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Развертывание успешно завершено!     ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Доступные сервисы:"
    echo "  - Backend API: http://localhost:8080"
    echo "  - API Docs: http://localhost:8080/swagger/index.html"
    echo "  - Grafana: http://localhost:3000 (admin/admin123)"
    echo "  - RabbitMQ Management: http://localhost:15672 (guest/guest)"
    echo ""
    echo "Команды для мониторинга:"
    echo "  docker-compose -f docker-compose.production.yml logs -f"
    echo "  docker-compose -f docker-compose.production.yml ps"
    echo ""
}

# Запуск
main "$@"
EOF
)"

    chmod +x "$BACKEND_DIR/scripts/deploy.sh"

    create_file "$BACKEND_DIR/scripts/healthcheck.sh" "$(cat <<'EOF'
#!/bin/bash

# Скрипт для проверки здоровья системы AutoJobSearch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Проверка HTTP эндпоинта
check_http() {
    local url="$1"
    local name="$2"

    if curl -s --max-time 5 "$url" | grep -q '"status":"ok"'; then
        echo -e "${GREEN}✓${NC} $name: UP"
        return 0
    else
        echo -e "${RED}✗${NC} $name: DOWN"
        return 1
    fi
}

# Проверка порта
check_port() {
    local host="$1"
    local port="$2"
    local name="$3"

    if nc -z -w5 "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $name: LISTENING"
        return 0
    else
        echo -e "${RED}✗${NC} $name: CLOSED"
        return 1
    fi
}

# Проверка базы данных
check_database() {
    local cmd="PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c 'SELECT 1'"

    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} PostgreSQL: CONNECTED"
        return 0
    else
        echo -e "${RED}✗${NC} PostgreSQL: ERROR"
        return 1
    fi
}

# Проверка Redis
check_redis() {
    local cmd="redis-cli -h $REDIS_HOST -p $REDIS_PORT"

    if [[ -n "$REDIS_PASSWORD" ]]; then
        cmd="$cmd -a $REDIS_PASSWORD"
    fi

    if eval "$cmd ping" 2>/dev/null | grep -q "PONG"; then
        echo -e "${GREEN}✓${NC} Redis: CONNECTED"
        return 0
    else
        echo -e "${RED}✗${NC} Redis: ERROR"
        return 1
    fi
}

# Проверка RabbitMQ
check_rabbitmq() {
    local cmd="curl -s -u $RABBITMQ_USER:$RABBITMQ_PASSWORD http://$RABBITMQ_HOST:15672/api/overview"

    if eval "$cmd" 2>/dev/null | grep -q "rabbitmq_version"; then
        echo -e "${GREEN}✓${NC} RabbitMQ: CONNECTED"
        return 0
    else
        echo -e "${RED}✗${NC} RabbitMQ: ERROR"
        return 1
    fi
}

# Основная проверка
main_check() {
    echo "========================================"
    echo "  AutoJobSearch Health Check"
    echo "========================================"
    echo ""

    # Загрузка переменных окружения
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    fi

    # Установка значений по умолчанию
    DB_HOST=${DB_HOST:-localhost}
    DB_PORT=${DB_PORT:-5432}
    DB_USER=${DB_USER:-postgres}
    DB_PASSWORD=${DB_PASSWORD:-postgres}
    DB_NAME=${DB_NAME:-autojobsearch}

    REDIS_HOST=${REDIS_HOST:-localhost}
    REDIS_PORT=${REDIS_PORT:-6379}
    REDIS_PASSWORD=${REDIS_PASSWORD:-}

    RABBITMQ_HOST=${RABBITMQ_HOST:-localhost}
    RABBITMQ_USER=${RABBITMQ_USER:-guest}
    RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-guest}

    local errors=0

    # Проверка инфраструктуры
    echo "--- Infrastructure ---"
    check_port "$DB_HOST" "$DB_PORT" "PostgreSQL" || ((errors++))
    check_port "$REDIS_HOST" "$REDIS_PORT" "Redis" || ((errors++))
    check_port "$RABBITMQ_HOST" "5672" "RabbitMQ" || ((errors++))
    echo ""

    # Проверка сервисов
    echo "--- Services ---"
    check_http "http://localhost:8080/health" "Backend API" || ((errors++))
    check_http "http://localhost:3000" "Grafana" || ((errors++))
    echo ""

    # Проверка подключений
    echo "--- Connections ---"
    check_database || ((errors++))
    check_redis || ((errors++))
    check_rabbitmq || ((errors++))
    echo ""

    # Проверка диска
    echo "--- Disk Usage ---"
    df -h / | tail -1
    echo ""

    # Проверка памяти
    echo "--- Memory Usage ---"
    free -h | head -2
    echo ""

    # Итог
    echo "========================================"
    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}✅ All systems operational${NC}"
    else
        echo -e "${RED}❌ Found $errors issue(s)${NC}"
    fi
    echo "========================================"

    return $errors
}

# Запуск
main_check
EOF
)"

    chmod +x "$BACKEND_DIR/scripts/healthcheck.sh"

    echo "✅ Скрипты администрирования созданы"
    echo ""

    # 8. СОЗДАНИЕ ФАЙЛОВ ДЛЯ KUBERNETES
    echo "8. Создание конфигураций Kubernetes..."

    create_dir "$BACKEND_DIR/k8s"

    create_file "$BACKEND_DIR/k8s/namespace.yaml" "$(cat <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: autojobsearch-production
  labels:
    name: autojobsearch-production
    environment: production
EOF
)"

    create_file "$BACKEND_DIR/k8s/configmap-production.yaml" "$(cat <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: autojobsearch-config
  namespace: autojobsearch-production
data:
  ENV: "production"
  DB_HOST: "postgres-service"
  DB_PORT: "5432"
  DB_NAME: "autojobsearch"
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
  RABBITMQ_URL: "amqp://rabbitmq-service:5672"
EOF
)"

    create_file "$BACKEND_DIR/k8s/deployment.yaml" "$(cat <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: autojobsearch-backend
  namespace: autojobsearch-production
  labels:
    app: autojobsearch-backend
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: autojobsearch-backend
  template:
    metadata:
      labels:
        app: autojobsearch-backend
    spec:
      containers:
      - name: backend
        image: autojobsearch/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
        envFrom:
        - configMapRef:
            name: autojobsearch-config
        - secretRef:
            name: autojobsearch-secrets
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: models-volume
          mountPath: /app/models
        - name: logs-volume
          mountPath: /app/logs
      volumes:
      - name: models-volume
        emptyDir: {}
      - name: logs-volume
        emptyDir: {}
      restartPolicy: Always
EOF
)"

    create_file "$BACKEND_DIR/k8s/service.yaml" "$(cat <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: autojobsearch-service
  namespace: autojobsearch-production
spec:
  selector:
    app: autojobsearch-backend
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  type: ClusterIP
EOF
)"

    create_file "$BACKEND_DIR/k8s/ingress.yaml" "$(cat <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: autojobsearch-ingress
  namespace: autojobsearch-production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - api.autojobsearch.com
    secretName: autojobsearch-tls
  rules:
  - host: api.autojobsearch.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: autojobsearch-service
            port:
              number: 80
EOF
)"

    echo "✅ Конфигурации Kubernetes созданы"
    echo ""

    echo "========================================"
    echo "✅ Вся инфраструктура создана успешно!"
    echo "========================================"
    echo ""
    echo "Созданы следующие компоненты:"
    echo "1. ✅ Миграции базы данных (PostgreSQL)"
    echo "2. ✅ Код для работы с БД"
    echo "3. ✅ Redis кэш"
    echo "4. ✅ Очереди RabbitMQ"
    echo "5. ✅ E2E шифрование"
    echo "6. ✅ ML инфраструктура"
    echo "7. ✅ Скрипты администрирования"
    echo "8. ✅ Конфигурации Kubernetes"
    echo ""
    echo "Для запуска инфраструктуры выполните:"
    echo "cd $BACKEND_DIR"
    echo "docker-compose -f docker-compose.production.yml up -d"
    echo ""
    echo "Для запуска миграций:"
    echo "./scripts/migrate.sh up"
    echo ""
    echo "Для проверки здоровья:"
    echo "./scripts/healthcheck.sh"
}

# Проверка переменных окружения
if [[ -z "$BACKEND_DIR" ]]; then
    echo "Ошибка: BACKEND_DIR не определена"
    echo "Запустите скрипт через create_backend.sh"
    exit 1
fi

# Запуск основной функции
create_infrastructure