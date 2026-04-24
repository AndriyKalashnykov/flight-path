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
│  healthcheck.go ServerHealthCheck │
│  api.go        FindItinerary      │
└───────────────┬──────────────────┘
                │
┌───────────────▼──────────────────┐
│          pkg/api/                 │
│  data.go       Flight struct      │
│  version.txt   Semantic version   │
└──────────────────────────────────┘
```

## Project Structure

```
flight-path/
├── main.go                          # Entry point
├── internal/                        # Private application code
│   ├── handlers/                    # HTTP handlers + business logic
│   │   ├── handlers.go              # Handler struct (dependency container)
│   │   ├── flight.go                # POST /calculate handler
│   │   ├── healthcheck.go           # GET / handler
│   │   ├── api.go                   # FindItinerary algorithm (O(n), plain maps)
│   │   ├── api_test.go              # Unit tests for FindItinerary
│   │   ├── api_bench_test.go        # Benchmarks for FindItinerary
│   │   ├── api_fuzz_test.go         # Fuzz tests for FindItinerary
│   │   ├── flight_test.go           # Handler tests for FlightCalculate
│   │   └── healthcheck_test.go      # Handler tests for ServerHealthCheck
│   └── app/                        # Echo bootstrap (middleware + routes)
│       ├── app.go                   # New() builds Echo, Port() returns SERVER_PORT
│       └── app_integration_test.go  # //go:build integration — full HTTP stack
│   └── routes/                      # Route registration
│       ├── flight.go                # Flight routes
│       ├── healthcheck.go           # Health routes
│       └── swagger.go               # Swagger routes
├── pkg/api/                         # Public types (importable by others)
│   ├── data.go                      # Flight struct, TestFlights fixture
│   └── version.txt                  # Semantic version
├── docs/                            # Auto-generated Swagger (do not edit)
├── specs/                           # Reverse-engineered specifications
├── test/                            # Newman/Postman E2E collection (18 cases)
├── benchmarks/                      # Saved benchmark results
├── scripts/                         # Build + wait-for-server helpers
├── .github/workflows/               # CI/CD pipelines
├── Dockerfile                       # Multi-stage container build
├── Makefile                         # Build automation
└── .env                             # Environment variables
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
| Entry point | `main.go` | Parse flags, load `.env`, call `app.New()`, start server on `app.Port()` |
| Bootstrap | `internal/app/` | Build Echo instance, register middleware + routes (shared by `main.go` and integration tests) |
| Routes | `internal/routes/` | URL-to-handler mapping |
| Handlers | `internal/handlers/*.go` | HTTP binding, validation, response |
| Business logic | `internal/handlers/api.go` | Core algorithm (`FindItinerary`) |
| Data models | `pkg/api/` | Shared types and fixtures |

### Middleware Stack

Registered in `internal/app/app.go` in this order:

1. `RequestLogger` — request access log
2. `Recover` — panic → 500
3. `CORS` — `CORS_ORIGIN` env var (defaults to `*`)
4. `Secure` — XSS, nosniff, X-Frame-Options: DENY, Referrer-Policy: strict-origin-when-cross-origin
5. Custom headers — `Cache-Control: no-store`, `Cross-Origin-Resource-Policy: same-origin`

### Configuration

- `.env` loaded via `godotenv`, overridable with `--env-file` flag
- `SERVER_PORT` — server port (default `8080`)
- `CORS_ORIGIN` — single allowed origin for CORS (default `*`)

## Dependencies

| Package | Purpose |
|---|---|
| `echo/v5` | HTTP framework |
| `godotenv` | Load `.env` files |
| `swaggo/echo-swagger/v2` | Serve Swagger UI |
| `swaggo/swag` | Generate OpenAPI spec from annotations |
