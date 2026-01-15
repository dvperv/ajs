#!/bin/bash

# Скрипт для создания структуры pkg/

source "$(dirname "$0")/create_helpers.sh"

create_pkg_structure() {
    echo "Создание структуры pkg/..."

    # Создание всех поддиректорий pkg
    create_dir "$BACKEND_DIR/pkg/logger"
    create_dir "$BACKEND_DIR/pkg/validator"
    create_dir "$BACKEND_DIR/pkg/scheduler"
    create_dir "$BACKEND_DIR/pkg/utils"
    create_dir "$BACKEND_DIR/pkg/hhapi"

    # Создание logger
    create_go_file "$BACKEND_DIR/pkg/logger/logger.go" "logger" "$(cat <<'EOF'
import (
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
)

var log *zap.Logger

func Init(env string) {
    var config zap.Config

    if env == "production" {
        config = zap.NewProductionConfig()
    } else {
        config = zap.NewDevelopmentConfig()
        config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
    }

    config.EncoderConfig.TimeKey = "timestamp"
    config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder

    var err error
    log, err = config.Build()
    if err != nil {
        panic(err)
    }
}

func Info(msg string, fields ...zap.Field) {
    log.Info(msg, fields...)
}

func Error(msg string, fields ...zap.Field) {
    log.Error(msg, fields...)
}

func Warn(msg string, fields ...zap.Field) {
    log.Warn(msg, fields...)
}

func Debug(msg string, fields ...zap.Field) {
    log.Debug(msg, fields...)
}

func Fatal(msg string, fields ...zap.Field) {
    log.Fatal(msg, fields...)
}

func Sync() error {
    return log.Sync()
}
EOF
)"

    # Создание validator
    create_go_file "$BACKEND_DIR/pkg/validator/validator.go" "validator" "$(cat <<'EOF'
package validator

import (
    "regexp"
    "strings"
)

func ValidateEmail(email string) bool {
    emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
    return emailRegex.MatchString(email)
}

func ValidatePhone(phone string) bool {
    // Простая валидация российских номеров
    phoneRegex := regexp.MustCompile(`^\+7\d{10}$`)
    return phoneRegex.MatchString(phone)
}

func ValidatePassword(password string) (bool, []string) {
    var errors []string

    if len(password) < 8 {
        errors = append(errors, "Password must be at least 8 characters")
    }

    if !regexp.MustCompile(`[A-Z]`).MatchString(password) {
        errors = append(errors, "Password must contain at least one uppercase letter")
    }

    if !regexp.MustCompile(`[a-z]`).MatchString(password) {
        errors = append(errors, "Password must contain at least one lowercase letter")
    }

    if !regexp.MustCompile(`[0-9]`).MatchString(password) {
        errors = append(errors, "Password must contain at least one number")
    }

    if !regexp.MustCompile(`[!@#$%^&*]`).MatchString(password) {
        errors = append(errors, "Password must contain at least one special character")
    }

    return len(errors) == 0, errors
}

func SanitizeString(input string) string {
    // Удаление потенциально опасных символов
    input = strings.TrimSpace(input)
    input = regexp.MustCompile(`[<>"'&]`).ReplaceAllString(input, "")
    return input
}
EOF
)"

    # Создание utils
    create_go_file "$BACKEND_DIR/pkg/utils/crypto.go" "utils" "$(cat <<'EOF'
package utils

import (
    "crypto/rand"
    "crypto/sha256"
    "encoding/hex"
    "fmt"
    "io"
)

func GenerateRandomString(length int) (string, error) {
    bytes := make([]byte, length)
    if _, err := rand.Read(bytes); err != nil {
        return "", err
    }
    return hex.EncodeToString(bytes), nil
}

func HashString(input string) string {
    hash := sha256.Sum256([]byte(input))
    return hex.EncodeToString(hash[:])
}

func GenerateUUID() string {
    uuid := make([]byte, 16)
    if _, err := io.ReadFull(rand.Reader, uuid); err != nil {
        return ""
    }

    uuid[6] = (uuid[6] & 0x0f) | 0x40
    uuid[8] = (uuid[8] & 0x3f) | 0x80

    return fmt.Sprintf("%x-%x-%x-%x-%x",
        uuid[0:4], uuid[4:6], uuid[6:8], uuid[8:10], uuid[10:])
}

func GenerateDeviceID() (string, error) {
    return GenerateRandomString(32)
}
EOF
)"

    # Создание hhapi клиента
    create_go_file "$BACKEND_DIR/pkg/hhapi/client.go" "hhapi" "$(cat <<'EOF'
package hhapi

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "net/url"
    "time"
)

type Client struct {
    baseURL    string
    httpClient *http.Client
}

func NewClient(baseURL string) *Client {
    return &Client{
        baseURL: baseURL,
        httpClient: &http.Client{
            Timeout: 30 * time.Second,
        },
    }
}

func (c *Client) SearchVacancies(ctx context.Context, accessToken string, params map[string]string) (*VacanciesResponse, error) {
    endpoint := "/vacancies"

    // Добавление параметров
    query := url.Values{}
    for key, value := range params {
        query.Add(key, value)
    }

    req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+endpoint+"?"+query.Encode(), nil)
    if err != nil {
        return nil, err
    }

    req.Header.Set("Authorization", "Bearer "+accessToken)
    req.Header.Set("User-Agent", "AutoJobSearch/1.0")
    req.Header.Set("HH-User-Agent", "AutoJobSearch/1.0 (support@autojobsearch.com)")

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("HH API error: %s", resp.Status)
    }

    var vacanciesResponse VacanciesResponse
    if err := json.NewDecoder(resp.Body).Decode(&vacanciesResponse); err != nil {
        return nil, err
    }

    return &vacanciesResponse, nil
}

func (c *Client) GetVacancy(ctx context.Context, accessToken, vacancyID string) (*Vacancy, error) {
    endpoint := fmt.Sprintf("/vacancies/%s", vacancyID)

    req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+endpoint, nil)
    if err != nil {
        return nil, err
    }

    req.Header.Set("Authorization", "Bearer "+accessToken)
    req.Header.Set("User-Agent", "AutoJobSearch/1.0")

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("HH API error: %s", resp.Status)
    }

    var vacancy Vacancy
    if err := json.NewDecoder(resp.Body).Decode(&vacancy); err != nil {
        return nil, err
    }

    return &vacancy, nil
}

func (c *Client) ApplyToVacancy(ctx context.Context, accessToken, vacancyID string, application map[string]interface{}) error {
    endpoint := fmt.Sprintf("/applications/%s", vacancyID)

    body, err := json.Marshal(application)
    if err != nil {
        return err
    }

    req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+endpoint, bytes.NewReader(body))
    if err != nil {
        return err
    }

    req.Header.Set("Authorization", "Bearer "+accessToken)
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("User-Agent", "AutoJobSearch/1.0")

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
        return fmt.Errorf("HH API error: %s", resp.Status)
    }

    return nil
}
EOF
)"

    echo "Структура pkg/ создана"
}

# Запуск функции
create_pkg_structure