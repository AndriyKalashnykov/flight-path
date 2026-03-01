# CLAUDE.md

## Project Overview

**flight-path** is a Go REST API microservice that calculates flight paths from unordered flight segments. Given a list of [source, destination] pairs, it determines the complete path (starting airport to ending airport).

- **Language**: Go 1.26.0 (managed via gvm)
- **Framework**: Echo v5 (v5.0.4)
- **Docs**: Swagger/Swaggo (auto-generated)
- **Version**: See `pkg/api/version.txt`
- **Repo**: https://github.com/AndriyKalashnykov/flight-path

## Project Structure

```
flight-path/
├── main.go                              # Entry point, server setup, Swagger config, middleware
├── internal/handlers/
│   ├── handlers.go                      # Handler struct constructor (New())
│   ├── flight.go                        # FlightCalculate handler (POST /calculate)
│   ├── healthcheck.go                   # ServerHealthCheck handler (GET /)
│   ├── api.go                           # FindItinerary algorithm (core business logic)
│   ├── api_test.go                     # Unit tests for FindItinerary (table-driven)
│   ├── api_bench_test.go               # Benchmark tests for FindItinerary
│   ├── api_fuzz_test.go                # Fuzz tests for FindItinerary
│   ├── flight_test.go                  # Handler tests for FlightCalculate
│   └── healthcheck_test.go             # Handler tests for ServerHealthCheck
├── internal/routes/
│   ├── flight.go                        # Flight routes
│   ├── healthcheck.go                   # Health routes
│   └── swagger.go                       # Swagger routes
├── pkg/api/
│   ├── data.go                          # Flight struct + TestFlights test data
│   └── version.txt                      # Semantic version (e.g., v0.0.3)
├── docs/                                # Generated Swagger docs (don't edit manually)
├── specs/                               # Reverse-engineered specifications
├── test/
│   └── FlightPath.postman_collection.json  # E2E test collection (6 cases: 3 happy + 3 negative)
├── benchmarks/                          # Saved benchmark results (bench_YYYYMMDD_HHMMSS.txt)
├── scripts/                             # build.sh, build-image.sh
├── Dockerfile                           # Multi-stage, multi-platform Docker build (Alpine)
├── Makefile                             # All build/dev/test commands
├── .env                                 # SERVER_PORT=8080
└── renovate.json                        # Dependency auto-update config
```

## API

- **POST /calculate** — Accepts `[][]string` (e.g., `[["SFO","ATL"],["ATL","EWR"]]`), returns `[]string` (e.g., `["SFO","EWR"]`)
- **GET /** — Health check (returns status + version)
- **GET /swagger/*** — Swagger UI
- Server runs on `SERVER_PORT` from `.env` (default 8080)

## Core Algorithm

`FindItinerary()` in `internal/handlers/api.go` — builds source/destination sets using plain maps, finds the airport with no incoming edge (start) and no outgoing edge (end). O(n) time and space.

## Handler Pattern

Handlers are **methods on `Handler` struct**, not free functions:

```go
type Handler struct{}
func New() Handler { return Handler{} }
func (h Handler) FlightCalculate(c *echo.Context) error { ... }
func (h Handler) ServerHealthCheck(c *echo.Context) error { ... }
```

Routes receive `*Handler` and wire methods:

```go
func FlightRoutes(e *echo.Echo, h *handlers.Handler) {
    e.POST("/calculate", h.FlightCalculate)
}
```

## Common Commands

```bash
make deps           # Install tools (swag, golangci-lint, gosec, govulncheck, gitleaks, actionlint, benchstat, node, newman)
make api-docs       # Generate Swagger docs (run after changing Swagger comments)
make lint           # Run golangci-lint (60+ linters via .golangci.yml)
make sec            # Run gosec security scanner
make vulncheck      # Run Go vulnerability check on dependencies
make secrets        # Scan for hardcoded secrets (gitleaks)
make lint-ci        # Lint GitHub Actions workflow files (actionlint)
make test           # Run all tests (unit + handler tests via go test -v ./...)
make fuzz           # Run fuzz tests for 30 seconds
make bench          # Run benchmarks
make bench-save     # Save benchmark results with timestamp
make bench-compare  # Compare latest two benchmark runs
make build          # deps + lint + sec + vulncheck + secrets + api-docs + build binary
make run            # Build and run server locally
make e2e            # Run Newman/Postman E2E tests (server must be running)
make test-case-one  # curl test: [["SFO", "EWR"]]
make test-case-two  # curl test: [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three # curl test: 4-segment path
make update         # Update Go dependencies
make release        # Tag and push a new release
make build-image    # Build multi-platform Docker image
```

## Before Committing

```bash
make lint           # Code quality (60+ linters via .golangci.yml)
make sec            # Security scan (gosec)
make vulncheck      # Dependency vulnerability check (govulncheck)
make secrets        # Secrets detection (gitleaks)
make test           # Tests
make api-docs       # Update Swagger docs
make build          # Compile
```

## Specifications

Reverse-engineered specs live in `specs/` (see `specs/README.md` for index):

- `PRODUCT.md` — Problem statement, functional/non-functional requirements
- `API.md` — Endpoints, request/response formats, validation rules, middleware
- `ALGORITHM.md` — FindItinerary algorithm, complexity analysis
- `ARCHITECTURE.md` — Layered architecture, design patterns, project structure
- `BUILD.md` — Toolchain, build pipeline, dependency management
- `TESTING.md` — Unit, handler, benchmark, and E2E test coverage
- `DOCKER.md` — Multi-stage build, multi-platform images
- `CI-CD.md` — GitHub Actions pipelines, release process
- `DATA-MODELS.md` — Data types, wire formats, validation rules

Update specs when changing architecture, API, or testing strategy.

## Code Conventions

- **Error handling**: Always handle explicitly; return errors up the stack, log at handler level
- **Handlers**: Methods on `Handler` struct — bind input, validate, call business logic, return JSON
- **Algorithm logic**: Lives in `internal/handlers/api.go`, not in route registration
- **Routes**: Registered in `internal/routes/`, receive `*Handler`
- **Public types**: Go in `pkg/api/` (e.g., `Flight` struct with `Start`/`End` fields)
- **Generated docs**: Never edit `docs/` manually — use `make api-docs`
- **Swagger annotations**: Required on all public endpoints (see existing handlers for format)
- **Testing**: Table-driven tests preferred; benchmark critical paths
- **Input validation**: Validate before processing; return 400 for bad input, 500 for server errors
- **Naming**: Descriptive; handlers as methods (`FlightCalculate`, `ServerHealthCheck`)
- **Formatting**: `gofmt`; lines < 120 chars
- **Build flags**: `GOFLAGS=-mod=mod`
- **Commit messages**: Conventional commits (`feat:`, `fix:`, `perf:`, `chore:`, etc.)

## Refactoring Rules

- Write tests before refactoring; run `make test` before and after
- Don't change behavior during refactoring
- Benchmark before optimizing: `make bench-save` -> optimize -> `make bench-save` -> `make bench-compare`
- Don't manually edit generated code in `docs/`
- Prefer readability over cleverness; don't over-engineer

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `github.com/labstack/echo/v5` | v5.0.4 | Web framework |
| `github.com/swaggo/echo-swagger` | v1.5.0 | Swagger UI |
| `github.com/swaggo/swag` | v1.16.6 | Swagger generator |
| `github.com/joho/godotenv` | v1.5.1 | Environment variables |

## Dev Tools

| Tool | Purpose | Install |
|---|---|---|
| `golangci-lint` | Meta-linter (60+ linters via `.golangci.yml`) | `make deps` |
| `gosec` | Security scanner | `make deps` |
| `govulncheck` | Dependency vulnerability check | `make deps` |
| `gitleaks` | Secrets detection | `make deps` |
| `actionlint` | GitHub Actions linter | `make deps` |
| `benchstat` | Benchmark comparison | `make deps` |
| `swag` | Swagger generation | `make deps` |
| `newman` | E2E API testing | `make deps` |

## Troubleshooting

- **Port 8080 in use**: `lsof -ti:8080 | xargs kill -9` or `pkill -f server`
- **Tool not found** (`swag`, `golangci-lint`, etc.): Run `make deps` and ensure `$(go env GOPATH)/bin` is in PATH
- **Swagger UI shows stale docs**: Run `make api-docs`, restart server, hard-refresh browser
- **Tests fail after changes**: Run `go test -v ./...` for verbose output; `go clean -testcache` to clear cache
- **Build fails**: Check `go version` matches go.mod (1.26.0); run `go mod tidy` then `make build`
- **E2E tests fail**: Ensure server is running first (`make run &`, wait a few seconds, then `make e2e`)

## Environment

- Go 1.26.0 via gvm: `GOROOT=/home/andriy/.gvm/gos/go1.26.0`
- Node.js via nvm (for Newman)
- Environment variables loaded from `.env` (`SERVER_PORT=8080`)
