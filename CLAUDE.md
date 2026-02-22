# CLAUDE.md

## Project Overview

**flight-path** is a Go REST API microservice that calculates flight paths from unordered flight segments. Given a list of [source, destination] pairs, it determines the complete path (starting airport to ending airport).

- **Language**: Go 1.26.0 (managed via gvm)
- **Framework**: Echo v5
- **Docs**: Swagger/Swaggo (auto-generated)
- **Repo**: https://github.com/AndriyKalashnykov/flight-path

## Project Structure

```
flight-path/
├── main.go                              # Entry point, server setup, Swagger config
├── internal/handlers/
│   ├── handlers.go                      # Flight path calculation algorithm
│   ├── flight.go                        # Flight endpoint handler
│   ├── healthcheck.go                   # Health check handler
│   ├── api.go                           # API utilities
│   └── api_bench_test.go               # Benchmark tests
├── internal/routes/
│   ├── flight.go                        # Flight routes
│   ├── healthcheck.go                   # Health routes
│   └── swagger.go                       # Swagger routes
├── pkg/api/
│   ├── data.go                          # Public API types/data structures
│   └── version.txt                      # Semantic version
├── docs/                                # Generated Swagger docs (don't edit manually)
├── test/
│   └── FlightPath.postman_collection.json  # E2E test collection
├── benchmarks/                          # Saved benchmark results
├── scripts/                             # Build and utility scripts
├── Dockerfile                           # Multi-stage, multi-platform Docker build
├── Makefile                             # All build/dev/test commands
└── .env                                 # Environment variables
```

## API

- **POST /calculate** — Accepts `[][]string` (e.g., `[["SFO","ATL"],["ATL","EWR"]]`), returns `[]string` (e.g., `["SFO","EWR"]`)
- **GET /health** — Health check
- **GET /swagger/index.html** — Swagger UI
- Server runs on port 8080

## Core Algorithm

Builds a graph (map) from flight segments, finds the starting airport (no incoming edge), traverses to the ending airport. O(n) time and space.

## Common Commands

```bash
make deps           # Install tools (swag, golangci-lint, gosec, benchstat)
make api-docs       # Generate Swagger docs (run after changing Swagger comments)
make lint           # Run golangci-lint
make critic         # Run go-critic
make sec            # Run gosec security scanner
make test           # Run unit tests
make bench          # Run benchmarks
make bench-save     # Save benchmark results with timestamp
make bench-compare  # Compare latest two benchmark runs
make build          # Lint + sec + api-docs + build binary
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

Run these checks:

```bash
make lint           # Code quality
make critic         # Code review
make sec            # Security scan
make test           # Unit tests
make api-docs       # Update Swagger docs
make build          # Compile
```

## Code Conventions

- **Error handling**: Always handle explicitly; return errors up the stack, log at top level (handlers)
- **Handlers**: Keep thin — bind input, validate, call business logic, return JSON response
- **Algorithm logic**: Lives in `internal/handlers/`, not in route registration
- **Routes**: Registered separately in `internal/routes/`
- **Public types**: Go in `pkg/api/`
- **Generated docs**: Never edit `docs/` manually — use `make api-docs`
- **Swagger annotations**: Required on all public endpoints (see existing handlers for format)
- **Testing**: Table-driven tests preferred; benchmark critical paths
- **Input validation**: Validate before processing; return 400 for bad input, 500 for server errors
- **Naming**: Descriptive (`CalculateFlightPath`, `FlightSegment`); handlers suffixed by purpose
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

| Package | Purpose |
|---|---|
| `github.com/labstack/echo/v5` | Web framework |
| `github.com/swaggo/echo-swagger` | Swagger UI |
| `github.com/swaggo/swag` | Swagger generator |
| `github.com/joho/godotenv` | Environment variables |

## Dev Tools

| Tool | Purpose | Install |
|---|---|---|
| `golangci-lint` | Linter | `make deps` |
| `gosec` | Security scanner | `make deps` |
| `gocritic` | Code critic | `make critic` installs it |
| `benchstat` | Benchmark comparison | `make deps` |
| `swag` | Swagger generation | `make deps` |
| `newman` | E2E API testing | `npm install -g newman` |

## Troubleshooting

- **Port 8080 in use**: `lsof -ti:8080 | xargs kill -9` or `pkill -f server`
- **Tool not found** (`swag`, `golangci-lint`, etc.): Run `make deps` and ensure `$(go env GOPATH)/bin` is in PATH
- **Swagger UI shows stale docs**: Run `make api-docs`, restart server, hard-refresh browser
- **Tests fail after changes**: Run `go test -v ./...` for verbose output; `go clean -testcache` to clear cache
- **Build fails**: Check `go version` matches go.mod (1.26.0); run `go mod tidy` then `make build`
- **E2E tests fail**: Ensure server is running first (`make run &`, wait a few seconds, then `make e2e`)
- **Swagger generation errors**: Check `@` annotation syntax in handler comments; see existing handlers for reference

## Custom Slash Commands

- `/project:check` — Run full pre-commit checklist (lint, critic, sec, test, api-docs, build)
- `/project:new-endpoint` — Guided workflow to add a new API endpoint
- `/project:optimize` — Benchmark-optimize-compare performance workflow

## Environment

- Go 1.26.0 via gvm: `GOROOT=/home/andriy/.gvm/gos/go1.26.0`
- Node.js via nvm (for Newman)
- Environment variables loaded from `.env`
