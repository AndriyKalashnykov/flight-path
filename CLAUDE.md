# CLAUDE.md

## Project Overview

**flight-path** is a Go REST API microservice that calculates flight paths from unordered flight segments. Given a list of [source, destination] pairs, it determines the complete path (starting airport to ending airport).

- **Language**: Go 1.26.2 (via mise, optional — system Go works too)
- **Framework**: Echo v5 (v5.1.0)
- **Docs**: Swagger/Swaggo (auto-generated)
- **Version**: See `pkg/api/version.txt`
- **Repo**: https://github.com/AndriyKalashnykov/flight-path

## Project Structure

```
flight-path/
├── main.go                              # Entry point — parses flags, loads .env, calls app.New() + app.Port()
├── internal/app/
│   ├── app.go                           # App bootstrap (Echo instance + middleware + routes)
│   └── app_integration_test.go          # //go:build integration — full HTTP stack tests
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
│   └── version.txt                      # Semantic version
├── docs/                                # Generated Swagger docs + architecture/planning docs (ARCHITECTURE.md has Mermaid diagrams)
├── specs/                               # Reverse-engineered specifications (see specs/README.md for index)
├── test/
│   ├── FlightPath.postman_collection.json  # E2E test collection (11 cases: HealthCheck + 5 happy + 5 negative)
│   ├── package.json                     # Newman dependency manifest (pnpm)
│   ├── pnpm-lock.yaml                   # pnpm lock file (reproducible builds)
│   └── .npmrc                           # pnpm configuration
├── img/                                 # README screenshots (Swagger UI, Newman output)
├── benchmarks/                          # Saved benchmark results (bench_YYYYMMDD_HHMMSS.txt)
├── scripts/                             # build.sh, build-image.sh, wait-for-server.sh
├── .zap/rules.tsv                       # OWASP ZAP scan rules for DAST job
├── .golangci.yml                        # golangci-lint configuration (default: all)
├── Dockerfile                           # Multi-stage, multi-platform Docker build (Alpine)
├── .hadolint.yaml                       # Hadolint Dockerfile linter config
├── Makefile                             # All build/dev/test commands
├── .env                                 # SERVER_PORT=8080
├── .mise.toml                           # Go toolchain pin for mise (source of truth alongside go.mod)
├── .nvmrc                               # Node major-version pin (source of truth for NODE_VERSION)
├── .goreleaser.yml                      # GoReleaser release configuration (binaries only; images via docker job in ci.yml)
├── .claude/                             # Claude Code commands, agents, skills, rules, and settings
├── .claudeignore                        # Claude Code ignore patterns
├── .dockerignore                        # Docker build context exclusions
├── .gitignore                           # Git ignore patterns
├── go.mod                               # Go module definition (source of truth for Go version)
├── go.sum                               # Go module checksums
├── LICENSE                              # MIT license
├── MEMORY.md                            # Project-local Claude Code memory notes
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
make deps           # Install toolchain — `mise install` reads .mise.toml and provisions Go, Node, and every quality/security tool (golangci-lint, gosec, govulncheck, gitleaks, actionlint, shellcheck, hadolint, trivy, act, goreleaser). swag + benchstat stay Go-installed; newman via pnpm + corepack
make deps-check     # Show required Go version, mise status, and tool status
make api-docs       # Generate Swagger docs (run after changing Swagger comments)
make format         # Format Go code
make lint           # Run golangci-lint + hadolint (comprehensive linting via .golangci.yml)
make sec            # Run gosec security scanner
make vulncheck      # Run Go vulnerability check on dependencies
make secrets        # Scan for hardcoded secrets (gitleaks)
make lint-ci        # Lint GitHub Actions workflow files (actionlint + shellcheck)
make mermaid-lint   # Validate Mermaid diagrams in markdown files (minlag/mermaid-cli Docker)
make release-check  # Validate .goreleaser.yml syntax and config (goreleaser check)
make test           # Run unit + handler tests (go test -race -v ./...)
make integration-test # Run integration tests (full HTTP stack + middleware; //go:build integration)
make fuzz           # Run fuzz tests for 30 seconds
make bench          # Run benchmarks
make bench-save     # Save benchmark results with timestamp
make bench-compare  # Compare latest two benchmark runs
make static-check   # All static analysis (lint-ci + lint + sec + vulncheck + secrets + trivy-fs + mermaid-lint + release-check)
make build          # Generate Swagger docs + compile binary
make run            # Build and run server locally
make e2e            # Self-contained: build + start server + run Newman + stop server
make e2e-quick      # Run Newman/Postman E2E tests (requires server already running)
make test-case-one  # curl test: [["SFO", "EWR"]]
make test-case-two  # curl test: [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three # curl test: 4-segment path
make update         # Update Go dependencies
make release        # Tag and push a new release (runs full `ci` pipeline first)
make check          # Full pre-commit checklist (alias for make ci)
make ci             # Local CI pipeline (deps + format + static-check + test + integration-test + coverage-check + build + fuzz + deps-prune-check)
make ci-run         # Run GitHub Actions workflow locally using act
make coverage       # Run tests with coverage report
make coverage-check # Verify coverage meets 80% threshold
make clean          # Remove build artifacts and test cache
make image-build    # Build Docker image for local testing
make image-run      # Run Docker container locally (detached; use image-stop to tear down)
make image-stop     # Stop the locally running Docker container
make image-push     # Push Docker image to GHCR (requires GH_ACCESS_TOKEN)
make image-smoke-test # Smoke-test a pre-built Docker container (no rebuild)
make image-test     # Build and smoke-test Docker container
make image-scan     # Build Docker image and run Trivy scan (requires trivy)
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
| `GO_VERSION` | (auto-extracted from go.mod) | Go version auto-parsed from `go.mod` via regex (mise also reads `go.mod` natively) |
| `SWAG_VERSION` | 2.0.0-rc5 | Swagger code generator (Go install — no stable mise backend) |
| `BENCHSTAT_VERSION` | 0.0.0-20260409210113-8e83ce0f7b1c | Benchmark comparison (Go install) |
| `MERMAID_CLI_VERSION` | 11.12.0 | Mermaid diagram validator (Docker image) |
| `MISE_VERSION` | 2026.4.11 | Toolchain version manager bootstrap (reads `.mise.toml`) |
| `NODE_VERSION` | 24 | Node.js major version (source of truth: `.nvmrc` / `.mise.toml`; installed via mise) |

The quality/security toolchain (golangci-lint, gosec, govulncheck, gitleaks,
actionlint, shellcheck, hadolint, trivy, act, goreleaser) is pinned in
`.mise.toml` — one source of truth, consumed by both local dev (`make deps` →
`mise install --yes`) and CI (`jdx/mise-action`). Do not re-pin these tools in
the Makefile or workflow YAML.

## Testing Pyramid

Three layers, run in order of increasing cost:

| Layer | Target | Scope | Typical duration |
|-------|--------|-------|------------------|
| Unit + handler | `make test` | `go test -race ./...` over unit and handler tests (no HTTP stack) | seconds |
| Integration | `make integration-test` | `//go:build integration` — full HTTP stack (Echo + middleware + CORS + error envelope) via `httptest` | tens of seconds |
| End-to-end | `make e2e` | Builds the binary, starts the server, runs the Newman/Postman collection against localhost, tears down | minutes |

`make ci` / `make check` exercises all three plus fuzz and coverage — never skip a layer locally.

## Before Committing

```bash
make check          # Alias for `make ci` — full local pipeline (format + static-check + test + integration-test + coverage-check + build + fuzz + deps-prune-check)
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

All quality/security tools below are installed in one pass by
`mise install --yes` (run by `make deps`). Versions are pinned in `.mise.toml`.

| Tool | Purpose | Source |
|---|---|---|
| `golangci-lint` | Meta-linter (configured via `.golangci.yml`) | mise / `.mise.toml` |
| `gosec` | Security scanner | mise / `.mise.toml` (aqua:securego/gosec) |
| `govulncheck` | Dependency vulnerability check | mise / `.mise.toml` (go: backend) |
| `gitleaks` | Secrets detection | mise / `.mise.toml` |
| `actionlint` | GitHub Actions linter | mise / `.mise.toml` |
| `shellcheck` | Shell script linter (used by actionlint inside `run:` steps) | mise / `.mise.toml` |
| `hadolint` | Dockerfile linter | mise / `.mise.toml` |
| `trivy` | Vulnerability scanner (images + filesystem) | mise / `.mise.toml` |
| `act` | Local GitHub Actions runner | mise / `.mise.toml` |
| `goreleaser` | Release binary builder + `.goreleaser.yml` validator | mise / `.mise.toml` |
| `swag` | Swagger generation | `go install` (pinned via `SWAG_VERSION` in Makefile) |
| `benchstat` | Benchmark comparison | `go install` (pinned via `BENCHSTAT_VERSION` in Makefile) |
| `newman` | E2E API testing | `pnpm install` in `test/` (pinned in `test/package.json`) |
| `mermaid-cli` | Mermaid diagram validator (runs as Docker image) | `make mermaid-lint` (pulls image on demand) |

## CI/CD

GitHub Actions CI workflow runs on push to `main`, tags `v*`, and pull requests. The workflow always triggers; a `changes` detector job (`dorny/paths-filter`) gates every heavy job on whether the push touches code (negated glob over `**.md`, `docs/**`, `specs/**`, `LICENSE`, `.gitignore`, `.claudeignore`, `.claude/**`, `benchmarks/**`, image assets — with `CLAUDE.md` re-included as project config). Doc-only PRs only run `changes` (~10s) and `ci-pass` (which treats skipped jobs as success). Avoids the trigger-level `paths-ignore` deadlock with Repository Rulesets — the workflow always reports `ci-pass`, satisfying required-check gates.

Claude Code workflow (`claude.yml`) provides interactive mode (responds to `@claude` mentions, restricted to `OWNER`/`MEMBER`/`COLLABORATOR` author associations) and automated PR review on every non-draft PR. Claude CI Fix workflow (`claude-ci-fix.yml`) auto-triggers on CI failures via `workflow_run` (same-repo branches only) and uses a dual anti-recursion guard (bot-author check + `claude-fix-attempted` label) plus a 12K total input cap on CI logs to prevent prompt-injection context stuffing.

All jobs live in `.github/workflows/ci.yml` (single-file layout matching the `/ci-workflow` skill template). The release-side `goreleaser` (tag-only) and `docker` (every push, push/sign tag-gated) are serialized via `needs:` so a tag either produces both the GitHub Release object AND the GHCR image, or neither — no half-released tags.

| Job | Triggers | Steps |
|-----|----------|-------|
| **changes** | all | `dorny/paths-filter` — emits `code` output; downstream jobs gate on `needs.changes.outputs.code == 'true'` |
| **static-check** | code changes | `make static-check` (lint-ci + lint + sec + vulncheck + secrets + trivy-fs + mermaid-lint + release-check) |
| **build** | code changes | Build binary, upload `server-binary` artifact |
| **test** | code changes | Coverage threshold check (80%+), fuzz tests, upload coverage artifact |
| **integration-test** | code changes | `make integration-test` — full HTTP stack (middleware, CORS branches, error envelope, preflight) via httptest |
| **e2e** | code changes | Download binary (fallback rebuild), run server, Newman/Postman E2E tests. Canonical name for the mandatory end-to-end test job — wraps `make e2e`. Runs on every push AND under `act` via `make ci-run` (no `vars.ACT` guard). |
| **dast** | code changes (skipped in act) | Download binary (fallback rebuild), run server, OWASP ZAP API security scan |
| **goreleaser** | tag push only | GoReleaser builds multi-platform binaries, archives, checksums, changelog, and GitHub Release. Anchor of the multi-artifact release — `docker` is serialized after this so a tag either produces both artifacts or none. |
| **docker** | code changes; serialized after goreleaser on tag push | Gates 1–3 run every push: single-arch build + Trivy image scan (CRITICAL/HIGH blocking) + `make image-smoke-test`. Gate 4 multi-arch build runs every push (`push: ${{ startsWith(github.ref, 'refs/tags/') }}`). On `v*.*.*` tags: additionally logs in to GHCR, pushes with clean image index (Pattern A: `provenance: false` + `sbom: false`), installs cosign, and signs by digest. Catches Dockerfile + multi-arch regressions on the commit that introduced them, not on release day. |
| **ci-pass** | always | Aggregator gate (`if: always()`, `needs:` all upstream including changes + docker + goreleaser) — single required check for branch protection. Skipped jobs (changes.code=false on doc-only PRs, goreleaser on non-tag pushes, dast under act) are `result: 'skipped'`, which `contains(needs.*.result, 'failure')` treats as non-failure — ci-pass passes correctly. |

The `dast` job is skipped when running locally with `act` (`vars.ACT == 'true'`) because OWASP ZAP needs Docker-in-Docker. The `e2e` and `docker` jobs run cleanly under act: `e2e` rebuilds the binary locally when cross-job artifact download fails, and `docker` exercises all gates (the tag-gated push/sign steps are skipped on non-tag pushes). The `make ci-run` target generates a synthetic event payload via `--eventpath` so `dorny/paths-filter` can resolve `repository.default_branch` (which act omits by default).

There is no separate `release.yml` — the tag-push release pipeline lives inside `ci.yml` as tag-gated sibling jobs, so `ci-pass` aggregates both CI and release phases into a single green check.

Cleanup workflow runs weekly (Sundays at 00:00 UTC) to delete old workflow runs (retain 7 days, keep minimum 5) and prune caches from merged/deleted branches.

## Troubleshooting

- **Port 8080 in use**: `lsof -ti:8080 | xargs kill -9` or `pkill -f server`
- **Tool not found** (`swag`, `golangci-lint`, etc.): Run `make deps` and ensure `$(go env GOPATH)/bin` is in PATH
- **Swagger UI shows stale docs**: Run `make api-docs`, restart server, hard-refresh browser
- **Tests fail after changes**: Run `go test -v ./...` for verbose output; `go clean -testcache` to clear cache
- **Build fails**: Check `go version` matches go.mod (1.26.2); if mismatch, use mise (`mise install`) or reinstall, then run `go mod tidy` and `make build`
- **E2E tests fail**: Ensure server is running first (`make run &`, wait a few seconds, then `make e2e`)

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.

## Upgrade Tracking

Items to check each session until resolved (remove when done):

- [ ] **swag v2 GA**: `swaggo/swag` v2 is still RC (v2.0.0-rc5) — check `gh api repos/swaggo/swag/releases --jq '[.[] | select(.tag_name | startswith("v2"))][0].tag_name'` for stable release, then upgrade `SWAG_VERSION` in Makefile and `go.mod`
- [ ] **ZAP Automation Framework**: `zaproxy/action-api-scan` is actively maintained (not deprecated as of 2026-04-06). `zaproxy/action-af` exists as a more flexible alternative but has less activity. Re-evaluate if `action-api-scan` gets a deprecation notice
- [ ] **Newman DEP0176**: Newman 6.2.2 emits `[DEP0176] DeprecationWarning: fs.F_OK is deprecated` from `newman/lib/run/secure-fs.js:146`. No newer Newman version available (6.2.2 is latest). Check `pnpm view newman version` for a fix release
- [ ] **echo-swagger v2: remove swag v1 dep**: PR [swaggo/echo-swagger#146](https://github.com/swaggo/echo-swagger/pull/146) and issue [#147](https://github.com/swaggo/echo-swagger/issues/147) — migrates echo-swagger to swag/v2 exclusively, removing the transitive swag v1 dependency. Check `gh pr view 146 --repo swaggo/echo-swagger --json state --jq '.state'` — when merged, run `go get github.com/swaggo/echo-swagger/v2@latest && go mod tidy` to drop swag v1 from our go.mod

## Upgrade Backlog

Items identified by upgrade analysis. Review periodically, act when conditions change:

- [ ] **govulncheck Renovate "abandoned" false positive**: `golang.org/x/vuln/cmd/govulncheck` last release (v1.1.4) is ~15 months old, which trips Renovate's release-age abandonment heuristic. The repo is actively maintained (main-branch pushes within days, 0 open issues, official Go sub-repo under `golang/`), and the CVE database the tool consults at `vuln.go.dev` updates server-side independently of the CLI's release cadence. Locally suppressed in `renovate.json` via `abandonmentThreshold: "5 years"` for this depName. Upstream tracked in [renovatebot/renovate discussions#42727](https://github.com/renovatebot/renovate/discussions/42727) under *Suggest an Idea* (proposal: fold commit activity + `archived` flag into the abandonment heuristic, not just release age) — when that lands, consider removing the local override. Originally filed as issue [#42725](https://github.com/renovatebot/renovate/issues/42725), auto-closed by the Renovate bot per its Issues-are-for-maintainers policy and re-filed as the Discussion above.
- [ ] **Newman sandbox lag**: Newman 6.2.2 bundles postman-sandbox 4.7.1 (upstream 6.6.1) and postman-runtime 7.39.1 (upstream 7.53.0). Check `pnpm view newman version` for Newman 7.x or new 6.x
- [ ] **Postman Collection Format v3**: YAML-based format announced Mar 2026. Newman doesn't support it yet. Track Newman releases for v3 support
- [ ] **swaggo/swag v1 indirect dep**: `echo-swagger/v2` pulls in `swag v1` transitively. Fix submitted upstream as [swaggo/echo-swagger#146](https://github.com/swaggo/echo-swagger/pull/146). Will auto-resolve when PR is merged and we update echo-swagger

## Environment

- Go 1.26.2 via mise (reads `.mise.toml`); install with `curl -fsSL https://mise.jdx.dev/install.sh | bash`
- Node.js via mise (reads `.mise.toml` / `.nvmrc`); pnpm enabled via corepack
- Quality/security tools (golangci-lint, gosec, govulncheck, gitleaks, actionlint, shellcheck, hadolint, trivy, act, goreleaser) are mise-managed and surface on `PATH` via `$HOME/.local/share/mise/shims` (exported by the Makefile alongside `$HOME/.local/bin` for the mise installer itself)
- Environment variables loaded from `.env` (`SERVER_PORT=8080`)
