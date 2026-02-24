# Architecture Specification

## Overview

Single-service Go REST API using Echo v5, following a layered architecture pattern.

## Component Diagram

```
┌──────────────────────────────────┐
│            main.go                │
│  Load .env, middleware, routes    │
└───────────────┬──────────────────┘
                │
┌───────────────▼──────────────────┐
│       internal/routes/            │
│  flight.go      POST /calculate   │
│  healthcheck.go GET /             │
│  swagger.go     GET /swagger/*    │
└───────────────┬──────────────────┘
                │
┌───────────────▼──────────────────┐
│       internal/handlers/          │
│  handlers.go   Handler struct     │
│  flight.go     FlightCalculate    │
│  healthcheck.go HealthCheck       │
│  api.go        FindItinerary      │
└───────────────┬──────────────────┘
                │
┌───────────────▼──────────────────┐
│          pkg/api/                 │
│  data.go       Flight struct      │
│  version.txt   Semantic version   │
└──────────────────────────────────┘
```

## Design Patterns

### Handler Struct Pattern

Handlers are methods on `Handler` struct (dependency injection ready):

```go
type Handler struct{}
func New() Handler { return Handler{} }
func (h Handler) FlightCalculate(c *echo.Context) error { ... }
```

### Route Registration

Routes in `internal/routes/` receive `*handlers.Handler` and wire methods.

### Separation of Concerns

| Layer | Location | Responsibility |
|---|---|---|
| Entry point | `main.go` | Server bootstrap, middleware, config |
| Routes | `internal/routes/` | URL-to-handler mapping |
| Handlers | `internal/handlers/*.go` | HTTP binding, validation, response |
| Business logic | `internal/handlers/api.go` | Core algorithm |
| Data models | `pkg/api/` | Shared types and fixtures |

### Configuration

- `.env` loaded via `godotenv`, overridable with `--env-file` flag
- Single config: `SERVER_PORT` (default `8080`)

## Dependencies

| Package | Purpose |
|---|---|
| `echo/v5` | HTTP framework |
| `godotenv` | Load `.env` files |
| `swaggo/echo-swagger` | Serve Swagger UI |
| `swaggo/swag` | Generate OpenAPI spec from annotations |
