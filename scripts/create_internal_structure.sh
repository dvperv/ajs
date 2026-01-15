#!/bin/bash

# Скрипт для создания структуры internal/

source "$(dirname "$0")/create_helpers.sh"

create_internal_structure() {
    echo "Создание структуры internal/..."

    # Создание всех поддиректорий internal
    create_dir "$BACKEND_DIR/internal/app"
    create_dir "$BACKEND_DIR/internal/app/di"
    create_dir "$BACKEND_DIR/internal/domain/models"
    create_dir "$BACKEND_DIR/internal/domain/repository"
    create_dir "$BACKEND_DIR/internal/service"
    create_dir "$BACKEND_DIR/internal/handler"
    create_dir "$BACKEND_DIR/internal/handler/middleware"

    # Создание app/app.go
    create_go_file "$BACKEND_DIR/internal/app/app.go" "app" "$(cat <<'EOF'
import (
    "autojobsearch/backend/config"
    "autojobsearch/backend/internal/app/di"
    "autojobsearch/backend/pkg/logger"
)

type App struct {
    config *config.Config
    container *di.Container
    router *gin.Engine
}

func New(cfg *config.Config) (*App, error) {
    // Создание контейнера зависимостей
    container, err := di.NewContainer(cfg)
    if err != nil {
        return nil, err
    }

    // Создание роутера
    router := gin.New()

    // Middleware
    router.Use(gin.Logger())
    router.Use(gin.Recovery())
    router.Use(middleware.CORS())

    // Настройка маршрутов
    setupRoutes(router, container)

    app := &App{
        config:    cfg,
        container: container,
        router:    router,
    }

    return app, nil
}

func (a *App) Router() *gin.Engine {
    return a.router
}

func (a *App) StartBackgroundTasks() {
    logger.Info("Starting background tasks...")
    // Запуск планировщика, обработчика очередей и т.д.
}

func (a *App) StopBackgroundTasks() {
    logger.Info("Stopping background tasks...")
    // Остановка всех фоновых задач
}

func setupRoutes(router *gin.Engine, container *di.Container) {
    // Health check
    router.GET("/health", func(c *gin.Context) {
        c.JSON(200, gin.H{"status": "ok"})
    })

    // API v1
    v1 := router.Group("/api/v1")
    {
        // Auth routes
        auth := v1.Group("/auth")
        {
            auth.POST("/register", container.AuthHandler.Register)
            auth.POST("/login", container.AuthHandler.Login)
            auth.POST("/biometric", container.AuthHandler.BiometricLogin)
            auth.GET("/hh/connect", container.AuthHandler.ConnectHH)
            auth.GET("/hh/callback", container.AuthHandler.HHCallback)
        }

        // Search routes
        search := v1.Group("/search").Use(middleware.Auth(container.JWTService))
        {
            search.POST("", container.SearchHandler.Search)
            search.GET("/new", container.SearchHandler.GetNewVacancies)
            search.POST("/match", container.SearchHandler.CalculateMatch)
        }

        // Resume routes
        resumes := v1.Group("/resumes").Use(middleware.Auth(container.JWTService))
        {
            resumes.POST("/upload", container.ResumeHandler.Upload)
            resumes.POST("/constructor", container.ResumeHandler.CreateFromConstructor)
            resumes.POST("/chat", container.ResumeHandler.CreateFromChat)
            resumes.GET("", container.ResumeHandler.List)
            resumes.GET("/:id", container.ResumeHandler.Get)
            resumes.PUT("/:id", container.ResumeHandler.Update)
            resumes.DELETE("/:id", container.ResumeHandler.Delete)
        }

        // Auto-apply routes
        autoApply := v1.Group("/auto-apply").Use(middleware.Auth(container.JWTService))
        {
            autoApply.POST("/rules", container.AutoApplyHandler.SetRules)
            autoApply.GET("/rules", container.AutoApplyHandler.GetRules)
            autoApply.GET("/status", container.AutoApplyHandler.GetStatus)
            autoApply.POST("/toggle", container.AutoApplyHandler.Toggle)
        }

        // Sync routes
        sync := v1.Group("/sync").Use(middleware.Auth(container.JWTService))
        {
            sync.GET("/operations", container.SyncHandler.GetOperations)
            sync.POST("/operations", container.SyncHandler.PushOperations)
        }

        // User routes
        users := v1.Group("/users").Use(middleware.Auth(container.JWTService))
        {
            users.GET("/profile", container.UserHandler.GetProfile)
            users.PUT("/profile", container.UserHandler.UpdateProfile)
            users.GET("/settings", container.UserHandler.GetSettings)
            users.PUT("/settings", container.UserHandler.UpdateSettings)
            users.GET("/quota", container.UserHandler.GetQuota)
        }
    }
}
EOF
)"

    # Создание app/di/container.go
    create_go_file "$BACKEND_DIR/internal/app/di/container.go" "di" "$(cat <<'EOF'
import (
    "autojobsearch/backend/config"
    "autojobsearch/backend/internal/domain/repository"
    "autojobsearch/backend/internal/handler"
    "autojobsearch/backend/internal/infrastructure/database"
    "autojobsearch/backend/internal/service"
    "autojobsearch/backend/pkg/hhapi"
    "autojobsearch/backend/pkg/logger"
)

type Container struct {
    // Config
    Config *config.Config

    // Repositories
    UserRepo      repository.UserRepository
    ResumeRepo    repository.ResumeRepository
    VacancyRepo   repository.VacancyRepository
    SearchConfigRepo repository.SearchConfigRepository
    AuditRepo     repository.AuditRepository
    SyncRepo      repository.SyncRepository
    TokenRepo     repository.TokenRepository

    // Services
    UserService      *service.UserService
    AuthService      *service.AuthService
    ResumeService    *service.ResumeService
    VacancyService   *service.VacancyService
    SearchService    *service.SearchService
    SyncService      *service.SyncService
    AuditService     *service.AuditService
    SchedulerService *service.SchedulerService
    EncryptionService *service.EncryptionService
    MLService        *service.MLService
    HHProxyService   *service.HHProxyService
    JWTService       *service.JWTService

    // Handlers
    UserHandler      *handler.UserHandler
    AuthHandler      *handler.AuthHandler
    ResumeHandler    *handler.ResumeHandler
    VacancyHandler   *handler.VacancyHandler
    SearchHandler    *handler.SearchHandler
    SyncHandler      *handler.SyncHandler
    AutoApplyHandler *handler.AutoApplyHandler
    HHProxyHandler   *handler.HHProxyHandler
}

func NewContainer(cfg *config.Config) (*Container, error) {
    // Инициализация базы данных
    db, err := database.NewPostgres(cfg)
    if err != nil {
        return nil, err
    }

    // Инициализация репозиториев
    userRepo := repository.NewUserRepository(db)
    resumeRepo := repository.NewResumeRepository(db)
    vacancyRepo := repository.NewVacancyRepository(db)
    searchConfigRepo := repository.NewSearchConfigRepository(db)
    auditRepo := repository.NewAuditRepository(db)
    syncRepo := repository.NewSyncRepository(db)
    tokenRepo := repository.NewTokenRepository(db)

    // Инициализация HH API клиента
    hhClient := hhapi.NewClient(cfg.HH.APIURL)

    // Инициализация сервисов
    encryptionService := service.NewEncryptionService(cfg)
    jwtService := service.NewJWTService(cfg)
    mlService, err := service.NewMLService(cfg.ML.ModelPath, cfg.ML.CacheSize)
    if err != nil {
        return nil, err
    }

    auditService := service.NewAuditService(auditRepo)
    userService := service.NewUserService(userRepo, encryptionService)
    authService := service.NewAuthService(userRepo, jwtService, encryptionService)

    searchService := service.NewSearchService(
        userRepo,
        searchConfigRepo,
        vacancyRepo,
        hhClient,
        auditService,
        service.NewSchedulerService(),
    )

    syncService := service.NewSyncService(syncRepo)
    hhProxyService := service.NewHHProxyService(tokenRepo, hhClient, auditService)

    // Инициализация обработчиков
    userHandler := handler.NewUserHandler(userService)
    authHandler := handler.NewAuthHandler(authService)
    resumeHandler := handler.NewResumeHandler(resumeService)
    searchHandler := handler.NewSearchHandler(searchService, mlService)
    syncHandler := handler.NewSyncHandler(syncService)

    return &Container{
        Config:      cfg,
        UserRepo:    userRepo,
        ResumeRepo:  resumeRepo,
        VacancyRepo: vacancyRepo,
        UserService: userService,
        AuthService: authService,
        UserHandler: userHandler,
        AuthHandler: authHandler,
        SearchHandler: searchHandler,
        ResumeHandler: resumeHandler,
        SyncHandler: syncHandler,
        MLService:   mlService,
        JWTService:  jwtService,
    }, nil
}
EOF
)"

    # Создание файлов моделей (только основные, полный список в ТЗ)
    create_domain_models
    create_repositories
    create_services
    create_handlers

    echo "Структура internal/ создана"
}

create_domain_models() {
    echo "  Создание доменных моделей..."

    # Создаем только основные файлы моделей для примера
    create_go_file "$BACKEND_DIR/internal/domain/models/user.go" "models" "$(cat <<'EOF'
import (
    "time"
    "github.com/google/uuid"
)

type User struct {
    ID              uuid.UUID   `json:"id" db:"id"`
    Email           string      `json:"email" db:"email"`
    Phone           string      `json:"phone,omitempty" db:"phone"`
    CreatedAt       time.Time   `json:"created_at" db:"created_at"`
    UpdatedAt       time.Time   `json:"updated_at" db:"updated_at"`
    LastLoginAt     *time.Time  `json:"last_login_at,omitempty" db:"last_login_at"`
    IsActive        bool        `json:"is_active" db:"is_active"`
    IsVerified      bool        `json:"is_verified" db:"is_verified"`
    TwoFAEnabled    bool        `json:"two_fa_enabled" db:"two_fa_enabled"`
    TwoFAMethod     string      `json:"two_fa_method,omitempty" db:"two_fa_method"`
    BiometricKey    string      `json:"-" db:"biometric_key"`
    EncryptionKey   string      `json:"-" db:"encryption_key"`
    SearchQuota     SearchQuota `json:"search_quota" db:"search_quota"`
    DeviceID        string      `json:"device_id" db:"device_id"`
}

type SearchQuota struct {
    DailyLimit      int       `json:"daily_limit" db:"daily_limit"`
    UsedToday      int       `json:"used_today" db:"used_today"`
    LastSearchTime time.Time `json:"last_search_time" db:"last_search_time"`
    ResetAt        time.Time `json:"reset_at" db:"reset_at"`
}
EOF
)"

    create_go_file "$BACKEND_DIR/internal/domain/models/resume.go" "models" "$(cat <<'EOF'
import (
    "time"
    "github.com/google/uuid"
)

type Resume struct {
    ID              uuid.UUID        `json:"id" db:"id"`
    UserID          uuid.UUID        `json:"user_id" db:"user_id"`
    Title           string           `json:"title" db:"title"`
    ParsedData      ParsedResumeData `json:"parsed_data" db:"parsed_data"`
    RawText         string           `json:"raw_text,omitempty" db:"raw_text"`
    FileURL         string           `json:"file_url,omitempty" db:"file_url"`
    FileHash        string           `json:"file_hash,omitempty" db:"file_hash"`
    ParsingAccuracy float64          `json:"parsing_accuracy" db:"parsing_accuracy"`
    SourceType      string           `json:"source_type" db:"source_type"`
    IsActive        bool             `json:"is_active" db:"is_active"`
    CreatedAt       time.Time        `json:"created_at" db:"created_at"`
    UpdatedAt       time.Time        `json:"updated_at" db:"updated_at"`
    Version         int              `json:"version" db:"version"`
}

type ParsedResumeData struct {
    PersonalInfo    PersonalInfo     `json:"personal_info"`
    WorkExperience  []WorkExperience `json:"work_experience"`
    Education       []Education      `json:"education"`
    Skills          []Skill          `json:"skills"`
    Languages       []Language       `json:"languages"`
    Certifications  []Certification  `json:"certifications"`
    Summary         string           `json:"summary"`
    DesiredPosition string           `json:"desired_position"`
    SalaryExpectations SalaryRange   `json:"salary_expectations"`
    Location        LocationPrefs    `json:"location"`
}
EOF
)"
}

create_repositories() {
    echo "  Создание интерфейсов репозиториев..."

    create_go_file "$BACKEND_DIR/internal/domain/repository/interfaces.go" "repository" "$(cat <<'EOF'
import (
    "context"
    "autojobsearch/backend/internal/domain/models"
    "github.com/google/uuid"
)

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*models.User, error)
    FindByEmail(ctx context.Context, email string) (*models.User, error)
    Create(ctx context.Context, user *models.User) error
    Update(ctx context.Context, user *models.User) error
    UpdateSearchQuota(ctx context.Context, userID string, quota models.SearchQuota) error
    GetHHTokens(ctx context.Context, userID string) (*models.HHToken, error)
    SaveHHTokens(ctx context.Context, userID string, tokens *models.HHToken) error
}

type ResumeRepository interface {
    FindByID(ctx context.Context, id uuid.UUID) (*models.Resume, error)
    FindByUserID(ctx context.Context, userID uuid.UUID) ([]models.Resume, error)
    Save(ctx context.Context, resume *models.Resume) error
    Update(ctx context.Context, resume *models.Resume) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type VacancyRepository interface {
    FindByID(ctx context.Context, id string) (*models.Vacancy, error)
    FindNewSince(ctx context.Context, userID string, since time.Time) ([]models.Vacancy, error)
    Save(ctx context.Context, vacancy *models.Vacancy) error
    Update(ctx context.Context, vacancy *models.Vacancy) error
    MarkAsArchived(ctx context.Context, id string) error
}

type SearchConfigRepository interface {
    FindByUserID(ctx context.Context, userID uuid.UUID) ([]models.SearchConfig, error)
    Save(ctx context.Context, config *models.SearchConfig) error
    Update(ctx context.Context, config *models.SearchConfig) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type AuditRepository interface {
    Log(ctx context.Context, log *models.AuditLog) error
    FindByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.AuditLog, error)
}

type SyncRepository interface {
    SaveOperation(ctx context.Context, op *models.SyncOperation) error
    FindPendingOperations(ctx context.Context, userID uuid.UUID, deviceID string) ([]models.SyncOperation, error)
    MarkAsApplied(ctx context.Context, operationIDs []string) error
}

type TokenRepository interface {
    Save(ctx context.Context, token *models.Token) error
    FindByUserID(ctx context.Context, userID uuid.UUID) (*models.Token, error)
    Delete(ctx context.Context, id uuid.UUID) error
}
EOF
)"
}

create_services() {
    echo "  Создание сервисов..."

    # Создаем только основные файлы сервисов для примера
    create_go_file "$BACKEND_DIR/internal/service/interfaces.go" "service" "$(cat <<'EOF'
import (
    "context"
    "autojobsearch/backend/internal/domain/models"
)

type UserService interface {
    GetProfile(ctx context.Context, userID string) (*models.User, error)
    UpdateProfile(ctx context.Context, userID string, updates map[string]interface{}) error
    GetSettings(ctx context.Context, userID string) (*models.UserSettings, error)
    UpdateSettings(ctx context.Context, userID string, settings *models.UserSettings) error
    GetQuota(ctx context.Context, userID string) (*models.SearchQuota, error)
}

type AuthService interface {
    Register(ctx context.Context, email, password, deviceID string) (*models.User, string, error)
    Login(ctx context.Context, email, password string) (*models.User, string, error)
    BiometricLogin(ctx context.Context, biometricData, deviceID string) (*models.User, string, error)
    GenerateJWT(user *models.User) (string, error)
    ValidateJWT(tokenString string) (*models.User, error)
}

type SearchService interface {
    SearchVacancies(ctx context.Context, userID string, config *models.SearchConfig) ([]models.Vacancy, *models.SearchQuota, error)
    CanUserSearch(ctx context.Context, userID string) (bool, *models.SearchQuota, error)
    GetNewVacanciesSince(ctx context.Context, userID string, since time.Time) ([]models.Vacancy, error)
    CalculateMatch(ctx context.Context, resumeID, vacancyID string) (float64, *models.MatchAnalysis, error)
}
EOF
)"
}

create_handlers() {
    echo "  Создание обработчиков..."

    # Создаем только основные middleware
    create_go_file "$BACKEND_DIR/internal/handler/middleware/auth.go" "middleware" "$(cat <<'EOF'
package middleware

import (
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"
    "autojobsearch/backend/internal/service"
)

func Auth(jwtService service.JWTService) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
            c.Abort()
            return
        }

        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format"})
            c.Abort()
            return
        }

        token := parts[1]
        user, err := jwtService.ValidateJWT(token)
        if err != nil {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }

        // Сохраняем userID в контексте
        c.Set("userID", user.ID.String())
        c.Next()
    }
}
EOF
)"
}

# Запуск функции
create_internal_structure