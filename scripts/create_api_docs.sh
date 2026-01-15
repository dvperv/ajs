#!/bin/bash

# Скрипт для создания API документации

source "$(dirname "$0")/create_helpers.sh"

create_api_docs() {
    echo "Создание API документации..."

    # Создание директорий для API
    create_dir "$BACKEND_DIR/api"
    create_dir "$BACKEND_DIR/api/swagger"

    # Создание основной документации
    create_file "$BACKEND_DIR/api/swagger/docs.go" "$(cat <<'EOF'
package swagger

import "github.com/swaggo/swag"

// SwaggerInfo содержит метаинформацию Swagger
var SwaggerInfo = &swag.Spec{
    Version:          "1.0",
    Host:             "localhost:8080",
    BasePath:         "/api/v1",
    Schemes:          []string{"http", "https"},
    Title:            "AutoJobSearch API",
    Description:      "API для системы автоматического поиска работы",
    InfoInstanceName: "swagger",
    SwaggerTemplate:  docTemplate,
}

const docTemplate = `{
  "openapi": "3.0.0",
  "info": {
    "title": "AutoJobSearch API",
    "description": "API для системы автоматического поиска работы с полной приватностью данных",
    "version": "1.0.0",
    "contact": {
      "name": "AutoJobSearch Support",
      "email": "support@autojobsearch.com"
    }
  },
  "servers": [
    {
      "url": "http://localhost:8080",
      "description": "Development server"
    },
    {
      "url": "https://api.autojobsearch.com",
      "description": "Production server"
    }
  ],
  "paths": {
    "/auth/register": {
      "post": {
        "summary": "Регистрация пользователя",
        "tags": ["Auth"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/RegisterRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Успешная регистрация",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/AuthResponse"
                }
              }
            }
          },
          "400": {
            "description": "Неверный запрос"
          }
        }
      }
    },
    "/search": {
      "post": {
        "summary": "Поиск вакансий",
        "description": "Поиск вакансий с лимитом 1 раз в 24 часа",
        "tags": ["Search"],
        "security": [{"BearerAuth": []}],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/SearchRequest"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Успешный поиск",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/SearchResponse"
                }
              }
            }
          },
          "429": {
            "description": "Превышен лимит поисков"
          }
        }
      }
    }
  },
  "components": {
    "securitySchemes": {
      "BearerAuth": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT"
      }
    },
    "schemas": {
      "RegisterRequest": {
        "type": "object",
        "required": ["email", "password", "device_id"],
        "properties": {
          "email": {
            "type": "string",
            "format": "email",
            "example": "user@example.com"
          },
          "password": {
            "type": "string",
            "format": "password",
            "minLength": 8,
            "example": "SecurePass123!"
          },
          "device_id": {
            "type": "string",
            "example": "device-123"
          }
        }
      },
      "AuthResponse": {
        "type": "object",
        "properties": {
          "user": {
            "$ref": "#/components/schemas/User"
          },
          "token": {
            "type": "string",
            "example": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
          }
        }
      },
      "SearchRequest": {
        "type": "object",
        "required": ["query", "region"],
        "properties": {
          "query": {
            "type": "string",
            "example": "Go разработчик"
          },
          "region": {
            "type": "string",
            "example": "Москва"
          },
          "experience": {
            "type": "string",
            "enum": ["noExperience", "between1And3", "between3And6", "moreThan6"],
            "example": "between3And6"
          },
          "salary_min": {
            "type": "integer",
            "example": 200000
          },
          "preferred_time": {
            "type": "string",
            "example": "08:00"
          }
        }
      },
      "SearchResponse": {
        "type": "object",
        "properties": {
          "success": {
            "type": "boolean"
          },
          "count": {
            "type": "integer",
            "example": 42
          },
          "vacancies": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Vacancy"
            }
          },
          "quota": {
            "$ref": "#/components/schemas/SearchQuota"
          },
          "next_search_available_at": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "User": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "format": "uuid",
            "example": "123e4567-e89b-12d3-a456-426614174000"
          },
          "email": {
            "type": "string",
            "format": "email"
          },
          "is_active": {
            "type": "boolean"
          },
          "created_at": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Vacancy": {
        "type": "object",
        "properties": {
          "id": {
            "type": "string",
            "example": "12345678"
          },
          "title": {
            "type": "string",
            "example": "Senior Backend Developer"
          },
          "company": {
            "type": "string",
            "example": "TechCorp Inc."
          },
          "salary_from": {
            "type": "integer",
            "example": 300000
          },
          "salary_to": {
            "type": "integer",
            "example": 450000
          },
          "experience": {
            "type": "string",
            "example": "3-6 лет"
          },
          "published_at": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "SearchQuota": {
        "type": "object",
        "properties": {
          "daily_limit": {
            "type": "integer",
            "example": 1
          },
          "used_today": {
            "type": "integer",
            "example": 1
          },
          "last_search_time": {
            "type": "string",
            "format": "date-time"
          },
          "reset_at": {
            "type": "string",
            "format": "date-time"
          }
        }
      }
    }
  }
}`
EOF
)"

    # Создание README.md для фронтенда
    create_file "$BACKEND_DIR/README.md" "$(cat <<'EOF'
# AutoJobSearch Backend

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

# Запуск зависимостей
docker-compose -f docker-compose.production.yml up -d postgres redis rabbitmq

# Миграции базы данных
make migrate

# Запуск сервера
make run