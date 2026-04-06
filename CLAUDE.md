# CLAUDE.md

## Project Overview

**flight-path** is a Go REST API microservice that calculates flight paths from unordered flight segments. Given a list of [source, destination] pairs, it determines the complete path (starting airport to ending airport).

- **Language**: Go 1.26.1 (via gvm, optional — system Go works too)
- **Framework**: Echo v5 (v5.1.0)
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
├── docs/                                # Generated Swagger docs + architecture/planning docs
├── specs/                               # Reverse-engineered specifications
├── test/
│   ├── FlightPath.postman_collection.json  # E2E test collection (6 cases: 3 happy + 3 negative)
│   ├── package.json                     # Newman dependency manifest (pnpm)
│   └── .npmrc                           # pnpm configuration
├── benchmarks/                          # Saved benchmark results (bench_YYYYMMDD_HHMMSS.txt)
├── scripts/                             # build.sh, build-image.sh, wait-for-server.sh
├── .zap/rules.tsv                       # OWASP ZAP scan rules for DAST job
├── .golangci.yml                        # golangci-lint configuration (60+ linters)
├── Dockerfile                           # Multi-stage, multi-platform Docker build (Alpine)
├── Dockerfile.goreleaser                # Single-stage Dockerfile for GoReleaser releases
├── .hadolint.yaml                       # Hadolint Dockerfile linter config
├── Makefile                             # All build/dev/test commands
├── .env                                 # SERVER_PORT=8080
├── .goreleaser.yml                      # GoReleaser release configuration
├── .claude/                             # Claude Code session/config files
├── .claudeignore                        # Claude Code ignore patterns
├── .dockerignore                        # Docker build context exclusions
├── .gitignore                           # Git ignore patterns
├── LICENSE                              # MIT license
├── README.md                            # Project documentation
└── renovate.json                        # Dependency auto-update config
```

## API

- **POST /calculate** — Accepts `[][]string` (e.g., `[["SFO","ATL"],["ATL","EWR"]]`), returns `[]string` (e.g., `["SFO","EWR"]`)
- **GET /** — Health check (returns server status)
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
make help           # List available tasks
make deps           # Install tools (swag, golangci-lint, gosec, govulncheck, gitleaks, actionlint, benchstat, node, newman)
make deps-check     # Show required Go version, gvm status, and tool status
make deps-hadolint  # Install hadolint for Dockerfile linting
make deps-act       # Install act for running GitHub Actions locally
make deps-trivy     # Install trivy for local vulnerability scanning
make deps-renovate  # Install nvm for Node.js version management and pnpm for Renovate validation
make api-docs       # Generate Swagger docs (run after changing Swagger comments)
make format         # Format Go code
make lint           # Run golangci-lint + hadolint (60+ linters via .golangci.yml)
make sec            # Run gosec security scanner
make vulncheck      # Run Go vulnerability check on dependencies
make secrets        # Scan for hardcoded secrets (gitleaks)
make lint-ci        # Lint GitHub Actions workflow files (actionlint)
make test           # Run all tests (unit + handler tests via go test -v ./...)
make fuzz           # Run fuzz tests for 30 seconds
make bench          # Run benchmarks
make bench-save     # Save benchmark results with timestamp
make bench-compare  # Compare latest two benchmark runs
make static-check   # All static analysis (lint-ci + lint + sec + vulncheck + secrets)
make build          # Generate Swagger docs + compile binary
make run            # Build and run server locally
make e2e            # Run Newman/Postman E2E tests (server must be running)
make test-case-one  # curl test: [["SFO", "EWR"]]
make test-case-two  # curl test: [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three # curl test: 4-segment path
make update         # Update Go dependencies
make release        # Tag and push a new release (full checks + build)
make image-build    # Build Docker image (full checks + test)
make check          # Full pre-commit checklist (format + static-check + test + build)
make ci             # Local CI pipeline (deps + format + static-check + test + coverage-check + fuzz + build)
make ci-full        # Full CI with coverage threshold (format + static-check + coverage-check + fuzz + build)
make ci-run         # Run GitHub Actions workflow locally using act
make coverage       # Run tests with coverage report
make coverage-check # Verify coverage meets 80% threshold
make clean          # Remove build artifacts and test cache
make docker-build   # Build Docker image for local testing
make docker-run     # Run Docker container locally
make docker-test    # Build and smoke-test Docker container
make docker-scan    # Build Docker image and run Trivy scan (requires trivy)
make trivy-fs       # Run Trivy filesystem vulnerability scan (requires trivy)
make trivy-image    # Run Trivy image vulnerability scan (requires trivy)
make open-swagger   # Open browser with Swagger docs pointing to localhost
make renovate-validate # Validate Renovate configuration
make deps-prune     # Remove unused Go module dependencies
make deps-prune-check # Verify no prunable dependencies (CI gate)
```

## Key Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `APP_NAME` | flight-path | Application name (used in Docker tags) |
| `GO_VERSION` | (auto-extracted from go.mod) | Go version auto-parsed from `go.mod` via regex |
| `SWAG_VERSION` | 2.0.0-rc5 | Swagger code generator |
| `GOSEC_VERSION` | 2.25.0 | Go security scanner |
| `GOLANGCI_VERSION` | 2.11.4 | Go meta-linter |
| `GOVULNCHECK_VERSION` | 1.1.4 | Go vulnerability checker |
| `GITLEAKS_VERSION` | 8.30.1 | Secrets scanner |
| `ACTIONLINT_VERSION` | 1.7.12 | GitHub Actions linter |
| `BENCHSTAT_VERSION` | 0.0.0-20260312031701-16a31bc5fbd0 | Benchmark comparison |
| `HADOLINT_VERSION` | 2.14.0 | Dockerfile linter |
| `TRIVY_VERSION` | 0.69.3 | Vulnerability scanner |
| `ACT_VERSION` | 0.2.87 | Local GitHub Actions runner |
| `GVM_SHA` | dd652539... | Go version manager (pinned by commit SHA) |
| `NVM_VERSION` | 0.40.4 | Node.js version manager |
| `NODE_VERSION` | 24 | Node.js major version (pinned for nvm) |

## Before Committing

```bash
make check          # Runs: static-check (lint, sec, vulncheck, secrets, lint-ci) + test + build
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

## Direct Dependencies

| Package | Version | Purpose |
|---|---|---|
| `github.com/labstack/echo/v5` | v5.1.0 | Web framework |
| `github.com/swaggo/echo-swagger/v2` | v2.0.1 | Swagger UI |
| `github.com/swaggo/swag/v2` | v2.0.0-rc5 | Swagger generator |
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
| `hadolint` | Dockerfile linter | `make lint` (auto-installed via `deps-hadolint`) |
| `trivy` | Vulnerability scanner (images + filesystem) | `make deps-trivy` |
| `act` | Local GitHub Actions runner | `make deps-act` |

## CI/CD

GitHub Actions CI workflow runs on push to `main`, tags `v*`, pull requests, and is reusable via `workflow_call` (called by release.yml). Non-critical files are excluded via `paths-ignore` (docs, images, benchmarks, `.claude/**`, metadata) — `CLAUDE.md` is re-included via `!CLAUDE.md` negation. Tags and `workflow_call` are unaffected by `paths-ignore`.

| Job | Steps |
|-----|-------|
| **static-check** | golangci-lint, gosec, govulncheck, gitleaks, actionlint, Trivy filesystem scan |
| **builds** | Build binary, upload artifact |
| **tests** | Coverage threshold check (80%+), fuzz tests |
| **integration** | Download binary, run server, Newman/Postman E2E tests |
| **dast** | Run server, OWASP ZAP API security scan (after static-check + builds + tests) |
| **image-scan** | Build Docker image, Trivy vulnerability scan |
| **container-test** | Load Docker image, health-check, API smoke test |

Jobs `integration`, `dast`, and `container-test` are skipped when running locally with `act` (`vars.ACT == 'true'`) to avoid artifact-download and network issues.

Release workflow runs on tag pushes (`v*.*.*`), calling ci.yml via `workflow_call` for full CI validation, then executing GoReleaser for binary/container release.

Cleanup workflow runs weekly (Sundays at 00:00 UTC) to delete old workflow runs (retain 7 days, keep minimum 5).

## Troubleshooting

- **Port 8080 in use**: `lsof -ti:8080 | xargs kill -9` or `pkill -f server`
- **Tool not found** (`swag`, `golangci-lint`, etc.): Run `make deps` and ensure `$(go env GOPATH)/bin` is in PATH
- **Swagger UI shows stale docs**: Run `make api-docs`, restart server, hard-refresh browser
- **Tests fail after changes**: Run `go test -v ./...` for verbose output; `go clean -testcache` to clear cache
- **Build fails**: Check `go version` matches go.mod (1.26.1); if mismatch, use gvm (`gvm use go1.26.1`) or reinstall, then run `go mod tidy` and `make build`
- **E2E tests fail**: Ensure server is running first (`make run &`, wait a few seconds, then `make e2e`)

## Skills

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.yml` | `/ci-workflow` |

## Upgrade Tracking

Items to check each session until resolved (remove when done):

- [ ] **swag v2 GA**: `swaggo/swag` v2 is still RC (v2.0.0-rc5) — check `gh api repos/swaggo/swag/releases --jq '[.[] | select(.tag_name | startswith("v2"))][0].tag_name'` for stable release, then upgrade `SWAG_VERSION` in Makefile and `go.mod`
- [ ] **ZAP Automation Framework**: `zaproxy/action-api-scan` is actively maintained (not deprecated as of 2026-04-06). `zaproxy/action-af` exists as a more flexible alternative but has less activity. Re-evaluate if `action-api-scan` gets a deprecation notice
- [ ] **Newman DEP0176**: Newman 6.2.2 emits `[DEP0176] DeprecationWarning: fs.F_OK is deprecated` from `newman/lib/run/secure-fs.js:146`. No newer Newman version available (6.2.2 is latest). Check `pnpm view newman version` for a fix release
- [ ] **echo-swagger v2: remove swag v1 dep**: PR [swaggo/echo-swagger#146](https://github.com/swaggo/echo-swagger/pull/146) and issue [#147](https://github.com/swaggo/echo-swagger/issues/147) — migrates echo-swagger to swag/v2 exclusively, removing the transitive swag v1 dependency. Check `gh pr view 146 --repo swaggo/echo-swagger --json state --jq '.state'` — when merged, run `go get github.com/swaggo/echo-swagger/v2@latest && go mod tidy` to drop swag v1 from our go.mod

## Upgrade Backlog

Items identified by upgrade analysis. Review periodically, act when conditions change:

- [ ] **godotenv low activity**: Last commit 2025-10-21, last release v1.5.1 (Feb 2023). Functionally complete — no action unless repo goes archived. Fallback: stdlib `os.Getenv` + helper
- [ ] **Newman sandbox lag**: Newman 6.2.2 bundles postman-sandbox 4.7.1 (upstream 6.6.1) and postman-runtime 7.39.1 (upstream 7.53.0). Check `pnpm view newman version` for Newman 7.x or new 6.x
- [ ] **Postman Collection Format v3**: YAML-based format announced Mar 2026. Newman doesn't support it yet. Track Newman releases for v3 support
- [x] ~~**GoReleaser `dockers` deprecation**: Migrated to `dockers_v2` with separate `Dockerfile.goreleaser` (2026-04-06)~~
- [ ] **swaggo/swag v1 indirect dep**: `echo-swagger/v2` pulls in `swag v1` transitively. Fix submitted upstream as [swaggo/echo-swagger#146](https://github.com/swaggo/echo-swagger/pull/146). Will auto-resolve when PR is merged and we update echo-swagger

## Environment

- Go 1.26.1 via gvm: `GOROOT=/home/andriy/.gvm/gos/go1.26.1`
- Node.js via nvm (for Newman)
- Environment variables loaded from `.env` (`SERVER_PORT=8080`)
