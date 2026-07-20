# CLAUDE.md

## Project Overview

**flight-path** is a Go REST API microservice that calculates flight paths from unordered flight segments. Given a list of [source, destination] pairs, it determines the complete path (starting airport to ending airport).

- **Language**: Go 1.26.5 (via mise, optional — system Go works too)
- **Framework**: Echo v5 (v5.2.0)
- **Docs**: Swagger/Swaggo (auto-generated)
- **Version**: See `pkg/api/version.txt`
- **Repo**: https://github.com/AndriyKalashnykov/flight-path

## Project Structure

```
flight-path/
├── main.go                              # Entry point — parses flags, loads .env via internal/envfile, calls app.New() + app.Port()
├── internal/app/
│   ├── app.go                           # App bootstrap (Echo instance + middleware + routes; imports docs for Swagger spec init)
│   └── app_integration_test.go          # //go:build integration — full HTTP stack tests
├── internal/envfile/
│   ├── envfile.go                       # In-house .env parser (replaces godotenv) — Load() reads KEY=VALUE pairs into os.Setenv
│   └── envfile_test.go                  # Unit tests for env-file parsing
├── internal/handlers/
│   ├── handlers.go                      # Handler struct constructor (New())
│   ├── flight.go                        # FlightCalculate handler (POST /calculate)
│   ├── healthcheck.go                   # ServerHealthCheck handler (GET /)
│   ├── api.go                           # FindItinerary algorithm (core business logic) + ErrCircularPath / ErrDisconnectedGraph sentinels
│   ├── api_test.go                     # Unit tests for FindItinerary (table-driven, includes contract-violation cases)
│   ├── api_bench_test.go               # Benchmark tests for FindItinerary
│   ├── api_fuzz_test.go                # Fuzz tests: FuzzFindItinerary (algorithm) + FuzzFlightCalculate (HTTP layer)
│   ├── flight_test.go                  # Handler tests for FlightCalculate
│   └── healthcheck_test.go             # Handler tests for ServerHealthCheck
├── internal/routes/
│   ├── flight.go                        # Flight routes
│   ├── healthcheck.go                   # Health routes
│   └── swagger.go                       # Swagger routes
├── pkg/api/
│   ├── data.go                          # Flight struct + TestFlights test data
│   └── version.txt                      # Semantic version
├── docs/                                # Generated Swagger docs + architecture/planning docs (ARCHITECTURE.md: C4 Container PNG + Mermaid sequence/flow diagrams)
│   └── diagrams/                        # C4 architecture diagrams-as-code: *.puml sources + out/*.png rendered (committed; `make diagrams`)
├── specs/                               # Reverse-engineered specifications (see specs/README.md for index)
├── test/
│   ├── FlightPath.postman_collection.json  # E2E test collection (18 cases: 3 health/security + 1 swagger + 6 happy + 8 negative)
│   ├── package.json                     # Newman dependency manifest (pnpm)
│   ├── pnpm-lock.yaml                   # pnpm lock file (reproducible builds)
│   └── .npmrc                           # pnpm configuration
├── img/                                 # README screenshots (Swagger UI, Newman output)
├── benchmarks/                          # Saved benchmark results (bench_YYYYMMDD_HHMMSS.txt)
├── scripts/                             # build.sh (cross-compile matrix), pick-port.sh, wait-for-server.sh
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
make deps           # Install toolchain — `mise install` reads .mise.toml and provisions Go, Node, and every quality/security tool (golangci-lint, gosec, govulncheck, gitleaks, actionlint, shellcheck, hadolint, trivy, act, goreleaser, container-structure-test, swag, benchstat). newman is installed via pnpm + corepack
make deps-mise      # Bootstrap mise + install every tool pinned in .mise.toml
make deps-image     # Lean dependency target for image-* targets (mise tools only — no Node/pnpm/Newman)
make deps-go        # Lean dependency target for Go-only targets (mise tools only — no Node/pnpm/Newman)
make check-deps-tier # Verify only e2e/e2e-quick/renovate-validate depend on the full (Node-provisioning) deps
make deps-check     # Show required Go version, mise status, and tool status
make api-docs       # Generate Swagger docs (run after changing Swagger comments)
make format         # Format Go code (rewrites in place; for dev use)
make format-check   # Verify Go code is gofmt-clean (CI gate; non-mutating)
make lint           # Run golangci-lint + hadolint (comprehensive linting via .golangci.yml)
make sec            # Run gosec security scanner
make vulncheck      # Run Go vulnerability check on dependencies
make secrets        # Scan for hardcoded secrets (gitleaks)
make lint-ci        # Lint GitHub Actions workflow files (actionlint + shellcheck)
make lint-scripts-exec # Verify all shell scripts are executable (catches subagent 0644 writes)
make mermaid-lint   # Validate Mermaid diagrams in markdown files (minlag/mermaid-cli Docker)
make diagrams       # Render C4 PlantUML architecture diagrams to PNG (plantuml/plantuml Docker)
make diagrams-clean # Remove rendered diagram artefacts (forces full re-render)
make diagrams-check # Verify committed diagram PNGs match current .puml source + PLANTUML_VERSION (CI gate)
make release-check  # Validate .goreleaser.yml syntax and config (goreleaser check)
make test           # Run unit + handler tests (go test -race -v ./...)
make integration-test # Run integration tests (full HTTP stack + middleware; //go:build integration)
make fuzz           # Run fuzz tests for 30 seconds
make bench          # Run benchmarks
make bench-save     # Save benchmark results with timestamp
make bench-compare  # Compare two benchmark runs (auto-discovers latest two, or pass OLD=/NEW=)
make check-go-alignment # Verify Go version matches across go.mod and .mise.toml
make check-docs-go-version # Verify the Go version referenced in docs matches go.mod
make static-check   # All static analysis (check-go-alignment + check-docs-go-version + format-check + lint-ci + lint + sec + vulncheck + secrets + trivy-fs + mermaid-lint + diagrams-check + release-check)
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
make ci             # Local CI pipeline (deps-go + static-check + test + integration-test + coverage + coverage-check + build + fuzz + deps-prune-check)
make ci-run         # Run GitHub Actions workflow locally using act
make coverage       # Run tests with coverage report
make coverage-check # Verify coverage meets 80% threshold
make clean          # Remove build artifacts and test cache
make image-build    # Build Docker image for local testing
make image-run      # Run Docker container locally (detached; use image-stop to tear down)
make image-stop     # Stop the locally running Docker container
make image-push     # Push Docker image to GHCR (requires GH_ACCESS_TOKEN)
make image-smoke-test # Smoke-test a pre-built Docker container (no rebuild)
make image-structure-test # Validate Dockerfile metadata + binary properties (container-structure-test)
make image-test     # Build, smoke-test, and structure-test Docker container
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
| `ACT_UBUNTU_VERSION` | act-latest-20260601 | Dated `catthehacker/ubuntu` runner image `make ci-run` maps to `ubuntu-latest` (Renovate-tracked Docker tag) |
| `MERMAID_CLI_VERSION` | 11.15.0 | Mermaid diagram validator (Docker image — only ecosystem mise can't manage) |
| `PLANTUML_VERSION` | 1.2026.6 | C4 PlantUML renderer (`make diagrams`; Docker image). Renovate-tracked but **excluded from automerge** — a bump can change committed PNG bytes that the bot can't regenerate; a human runs `make diagrams` per bump (see Upgrade Tracking) |
| `MISE_VERSION` | 2026.5.13 | mise bootstrap version (used by `make deps` if mise isn't already installed) |
| `NODE_VERSION` | 24 | Node.js major version (source of truth: `.nvmrc` / `.mise.toml`; installed via mise) |

Every other tool — `go`, `node`, `golangci-lint`, `gosec`, `govulncheck`,
`gitleaks`, `actionlint`, `shellcheck`, `hadolint`, `trivy`, `act`,
`goreleaser`, `container-structure-test`, **`swag`**, and **`benchstat`** — is
pinned in `.mise.toml` and installed by `mise install --yes` (local) /
`jdx/mise-action` (CI). Do not re-pin them in the Makefile or workflow YAML.
The two earlier `SWAG_VERSION`/`BENCHSTAT_VERSION` Makefile constants were
retired in favor of the mise `go:` backend (`go:github.com/swaggo/swag/v2/cmd/swag`
and `go:golang.org/x/perf/cmd/benchstat`).

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
make check          # Alias for `make ci` — full local pipeline (deps + static-check + test + integration-test + coverage + coverage-check + build + fuzz + deps-prune-check)
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
| `github.com/labstack/echo/v5` | v5.2.0 | Web framework |
| `github.com/swaggo/echo-swagger/v2` | v2.0.1 | Swagger UI |
| `github.com/swaggo/swag/v2` | v2.0.0-rc5 | Swagger generator |

`.env` parsing is handled in-house by `internal/envfile` (no third-party
dependency).

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
| `container-structure-test` | Dockerfile metadata + binary property validator | mise / `.mise.toml` (aqua:GoogleContainerTools/container-structure-test) |
| `swag` | Swagger generation | mise / `.mise.toml` (go:github.com/swaggo/swag/v2/cmd/swag) |
| `benchstat` | Benchmark comparison | mise / `.mise.toml` (go:golang.org/x/perf/cmd/benchstat) |
| `newman` | E2E API testing | `pnpm install` in `test/` (pinned in `test/package.json`) |
| `mermaid-cli` | Mermaid diagram validator (runs as Docker image) | `make mermaid-lint` (pulls image on demand) |
| `plantuml` | C4 architecture diagram renderer (runs as Docker image) | `make diagrams` (pulls `plantuml/plantuml:$(PLANTUML_VERSION)` on demand) |

## CI/CD

GitHub Actions CI workflow runs on push to `main`, tags `v*`, and pull requests. The workflow always triggers; a `changes` detector job (`dorny/paths-filter`) gates every heavy job on whether the push touches code (negated glob over `**.md`, `docs/**`, `specs/**`, `LICENSE`, `.gitignore`, `.claudeignore`, `.claude/**`, `benchmarks/**`, image assets — with `CLAUDE.md` re-included as project config). Doc-only PRs only run `changes` (~10s) and `ci-pass` (which treats skipped jobs as success). Avoids the trigger-level `paths-ignore` deadlock with Repository Rulesets — the workflow always reports `ci-pass`, satisfying required-check gates.

Claude Code workflow (`claude.yml`) provides interactive mode only (responds to `@claude` mentions on issues, PR comments, and PR reviews, restricted to `OWNER`/`MEMBER`/`COLLABORATOR` author associations); it has no `pull_request` trigger and does not auto-review PRs. Claude CI Fix workflow (`claude-ci-fix.yml`) auto-triggers on CI failures via `workflow_run` (same-repo branches only) and uses a dual anti-recursion guard (bot-author check + `claude-fix-attempted` label) plus a 12K total input cap on CI logs to prevent prompt-injection context stuffing.

All jobs live in `.github/workflows/ci.yml` (single-file layout matching the `/ci-workflow` skill template). The release-side `goreleaser` and `docker` are **both tag-only** and are serialized via `needs:` so a tag either produces both the GitHub Release object AND the GHCR image, or neither — no half-released tags.

| Job | Triggers | Steps |
|-----|----------|-------|
| **changes** | all | `dorny/paths-filter` — emits `code` output; downstream jobs gate on `needs.changes.outputs.code == 'true'` |
| **static-check** | code changes | `make static-check` (lint-ci + lint + sec + vulncheck + secrets + trivy-fs + mermaid-lint + diagrams-check + release-check) |
| **build** | code changes | Build binary, upload `server-binary` artifact |
| **test** | code changes | Coverage threshold check (80%+), fuzz tests, upload coverage artifact |
| **integration-test** | code changes | `make integration-test` — full HTTP stack (middleware, CORS branches, error envelope, preflight) via httptest |
| **e2e** | code changes | Download binary (fallback rebuild), run server, Newman/Postman E2E tests. Canonical name for the mandatory end-to-end test job — wraps `make e2e`. Runs on every push AND under `act` via `make ci-run` (no `vars.ACT` guard). |
| **dast** | code changes (skipped in act) | Download binary (fallback rebuild), run server, OWASP ZAP API security scan |
| **goreleaser** | tag push only | GoReleaser builds multi-platform binaries, archives, checksums, changelog, and GitHub Release. Anchor of the multi-artifact release — `docker` is serialized after this so a tag either produces both artifacts or none. |
| **docker** | **tag push only**; serialized after goreleaser | Every image step is tag-gated: single-arch build + Trivy image scan (CRITICAL/HIGH blocking) + `make image-smoke-test` + container-structure-test, then multi-arch build, GHCR push with a clean image index (Pattern A: `provenance: false` + `sbom: false`), cosign install, and keyless signing by digest. **Nothing image-related runs on ordinary pushes or PRs.** Trade-off: Dockerfile and multi-arch regressions now surface at release time rather than on the commit that introduced them. |
| **ci-pass** | always | Aggregator gate (`if: always()`, `needs:` all upstream including changes + docker + goreleaser) — single required check for branch protection. Skipped jobs (changes.code=false on doc-only PRs, goreleaser and docker on non-tag pushes, dast under act) are `result: 'skipped'`, which `contains(needs.*.result, 'failure')` treats as non-failure — ci-pass passes correctly. |

The `dast` job is skipped when running locally with `act` (`vars.ACT == 'true'`) because OWASP ZAP needs Docker-in-Docker. The `e2e` and `docker` jobs run cleanly under act: `e2e` rebuilds the binary locally when cross-job artifact download fails, and `docker` exercises all gates (the tag-gated push/sign steps are skipped on non-tag pushes). The `make ci-run` target generates a synthetic event payload via `--eventpath` so `dorny/paths-filter` can resolve `repository.default_branch` (which act omits by default).

There is no separate `release.yml` — the tag-push release pipeline lives inside `ci.yml` as tag-gated sibling jobs, so `ci-pass` aggregates both CI and release phases into a single green check.

Auto-merge workflow (`auto-merge.yml`) enables GitHub native auto-merge (`gh pr merge --auto --squash`) on **non-draft PRs authored by the repo owner** (`github.event.pull_request.user.login == 'AndriyKalashnykov'`), triggered on `pull_request` `opened`/`ready_for_review`, so those PRs merge automatically the instant `ci-pass` goes green. (Renovate's own PRs are NOT handled here — they auto-merge via `renovate.json`'s `platformAutomerge`/`automerge`.) Consequence: do not add commits to one of your own open PRs expecting it to wait — it can merge out from under you on green CI; put follow-up work on a fresh branch. Prune workflow (`cleanup-runs.yml`) runs weekly (Sundays at 00:00 UTC) to delete old workflow runs (retain 7 days, keep minimum 5) and prune caches from merged/deleted branches. Nightly fuzz workflow (`nightly-fuzz.yml`) runs `FuzzFindItinerary` for 10 minutes daily at 03:17 UTC (vs 30 s in `ci.yml`), accumulates the corpus across runs via `internal/handlers/testdata/fuzz` cache, and opens (or appends to) a tracking issue labeled `nightly-fuzz-failure` on failure.

## Troubleshooting

- **Port 8080 in use**: `lsof -ti:8080 | xargs kill -9` or `pkill -f server`
- **Tool not found** (`swag`, `golangci-lint`, etc.): Run `make deps` and ensure `$(go env GOPATH)/bin` is in PATH
- **Swagger UI shows stale docs**: Run `make api-docs`, restart server, hard-refresh browser
- **Tests fail after changes**: Run `go test -v ./...` for verbose output; `go clean -testcache` to clear cache
- **Build fails**: Check `go version` matches the `go` directive in go.mod; if mismatch, use mise (`mise install`) or reinstall, then run `go mod tidy` and `make build`
- **E2E tests fail**: Ensure server is running first (`make run &`, wait a few seconds, then `make e2e`)

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |
| `docs/diagrams/*.puml`, architecture diagrams | `/architecture-diagrams` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.

## Upgrade Tracking

Items to check each session until resolved (remove when done):

- [ ] **swag v2 GA**: `swaggo/swag` v2 is still RC (v2.0.0-rc5) — check `gh api repos/swaggo/swag/releases --jq '[.[] | select(.tag_name | startswith("v2"))][0].tag_name'` for a stable release, then bump the swag pin in `.mise.toml` (the `go:github.com/swaggo/swag/v2/cmd/swag` backend entry) and `go.mod`

**Standing runbook — C4 diagram renderer bumps (do NOT remove):**

- **`PLANTUML_VERSION` Renovate PR (group "PlantUML renderer", `automerge: false`)** — the hosted bot can't render, so this PR is intentionally NOT auto-merged. When it opens: check it out, run `make diagrams`, and commit the regenerated `docs/diagrams/out/*.png` onto the PR branch. `diagrams-check` (in `static-check`) goes green and the PR can merge. If `make diagrams` produces no PNG change (byte-identical render across the bump), just merge — the gate is already green.
- **C4-PlantUML `!include` version** (pinned to `v2.13.0` in `docs/diagrams/*.puml`) is deliberately NOT Renovate-tracked (no customManager) — tracking it would create the same un-regenerable bot PR with no automerge benefit. Periodically bump by hand: `gh api repos/plantuml-stdlib/C4-PlantUML/releases/latest --jq .tag_name`, update both `.puml` files, `make diagrams`, commit source + PNG together.

## Upgrade Backlog

Items identified by upgrade analysis. Review periodically, act when conditions change:

- [x] ~~**Split `deps` so Go-only gates don't provision Node/pnpm/Newman**~~ — **DONE 2026-07-20.** `deps-go: deps-mise` added (mirroring `deps-image`); 24 Go-only targets repointed; `deps: deps-go` keeps `deps` a strict superset so `make deps` is unchanged for operators. Only `e2e`, `e2e-quick`, `renovate-validate` remain on full `deps`. Measured on static-check's closure: `corepack` 6→0 and `pnpm install` 1→0. (A `newman` grep now reads **2**, not 0 — those are `check-deps-tier`'s own error strings, not provisioning; grep `corepack`/`pnpm install` if you re-run this.) The end-result proof is that a clean-tree `make static-check` no longer creates `test/node_modules`, while `e2e-quick` still does. Enforced by `check-deps-tier`.
- [x] ~~**Gate that the Go-only closure never provisions Newman**~~ — **DONE 2026-07-20**, but *not* as originally specified. The planned `make -n static-check` token scan was designed, then **rejected on measurement**: static-check's closure covers only **7 of the 24** repointed targets, so it was blind to a regression in the other 17 — including `ci`, `test`, `build`, `coverage`. `check-deps-tier` instead keys on an **allowlist derived from the Makefile source** (catches all 24), carries a vacuity floor (`>=3` bare-`deps` targets, else it fails as VACUOUS rather than passing by not looking), and still excludes the `pnpm` token because `trivy-fs`'s `.pnpm-store` skip-dir would make it red on a correct tree. RED-proven twice: repointing `ci` (one of the 17 the rejected design could not see), and starving the corpus.
- [ ] **No per-push Trivy image scan since docker went tag-only** (2026-07-20). This matches the `/ci-workflow` skill's **tag-only default (updated 2026-07)**, and the skill's precondition holds here: `dast` builds the Dockerfile (amd64) and runs the container on every code push, so build/startup regressions still fail on the introducing commit. What genuinely moved to tag-cut: Trivy image CVE scan, `make image-smoke-test`, `make image-structure-test`, and the arm64 leg. **Release discipline: watch the tag run's `docker` job** — it is the first place an arm64 cross-compile or base-image CVE regression appears. If that proves too late, the middle ground is a cheap amd64 build + `image-smoke-test` on PRs, leaving multi-arch/push/sign tag-gated.
- [ ] **Is `Claude CI Fix` earning its keep?** It auto-fired 8× between 2026-07-14 and 07-19 against the same broken PR and never fixed it (the fix needed diffing an upstream action's source, which its scoped `Bash(make …)` allowlist cannot reach). Either widen its remit, or accept it as best-effort and stop reading its green "success" conclusion as evidence anything was repaired.

Note: `docs/IMPLEMENTATION-PLAN.md` still shows an `npm install -g newman` / nvm-based `deps` recipe. That is a **historical planning document** — a record of what was decided at the time — and is deliberately left as-is rather than rewritten. Live-state docs describing the current pnpm/corepack mechanism are kept current.

- [ ] **govulncheck Renovate "abandoned" false positive**: `golang.org/x/vuln/cmd/govulncheck` last release (v1.1.4) is ~15 months old, which trips Renovate's release-age abandonment heuristic. The repo is actively maintained (main-branch pushes within days, 0 open issues, official Go sub-repo under `golang/`), and the CVE database the tool consults at `vuln.go.dev` updates server-side independently of the CLI's release cadence. Locally suppressed in `renovate.json` via `abandonmentThreshold: "5 years"` for this depName. Upstream tracked in [renovatebot/renovate discussions#42727](https://github.com/renovatebot/renovate/discussions/42727) under *Suggest an Idea* (proposal: fold commit activity + `archived` flag into the abandonment heuristic, not just release age) — when that lands, consider removing the local override. Originally filed as issue [#42725](https://github.com/renovatebot/renovate/issues/42725), auto-closed by the Renovate bot per its Issues-are-for-maintainers policy and re-filed as the Discussion above.
- [ ] **Newman version lag**: Newman 6.2.2 is the latest release but ships stale internals — it emits `[DEP0176] DeprecationWarning: fs.F_OK is deprecated` (from `newman/lib/run/secure-fs.js:146`), bundles postman-sandbox 4.7.1 (upstream 6.6.1) + postman-runtime 7.39.1 (upstream 7.53.0), and carries an open moderate `pnpm audit` finding GHSA-w5hq-g745-h8pq (`uuid` <11.1.1, transitive via `postman-collection` — resolves to 3.4.0 / 8.3.2). The `uuid` advisory canNOT be safely fixed with a `pnpm-workspace.yaml` override: patched `uuid` is ≥11.1.1, a breaking API major over the v3/v8 the tree uses. All three resolve only with a newer Newman — check `pnpm view newman version` for Newman 7.x or a new 6.x release
- [ ] **Postman Collection Format v3**: YAML-based format announced Mar 2026. Newman doesn't support it yet. Track Newman releases for v3 support
- [ ] **swaggo/swag v1 indirect dep**: `echo-swagger/v2` (latest `v2.0.1`) still pulls in `swag v1` (`v1.16.6`) transitively. The original upstream fix [swaggo/echo-swagger#146](https://github.com/swaggo/echo-swagger/pull/146) was **closed unmerged on 2026-05-31**; tracking issue [#147](https://github.com/swaggo/echo-swagger/issues/147) remains **open**. No echo-swagger release drops swag v1 yet. Re-check periodically: `gh issue view 147 --repo swaggo/echo-swagger --json state --jq '.state'` and `gh api repos/swaggo/echo-swagger/releases --jq '[.[]|select(.tag_name|startswith("v2"))][0].tag_name'`; when a release lands that removes the swag v1 edge, run `go get github.com/swaggo/echo-swagger/v2@latest && go mod tidy` to drop it from `go.mod`

## Environment

- Go 1.26.5 via mise (reads `.mise.toml`); install with `curl -fsSL https://mise.jdx.dev/install.sh | bash`
- Node.js via mise (reads `.mise.toml` / `.nvmrc`); pnpm enabled via corepack
- Quality/security tools (golangci-lint, gosec, govulncheck, gitleaks, actionlint, shellcheck, hadolint, trivy, act, goreleaser) are mise-managed and surface on `PATH` via `$HOME/.local/share/mise/shims` (exported by the Makefile alongside `$HOME/.local/bin` for the mise installer itself)
- Environment variables loaded from `.env` (`SERVER_PORT=8080`)
