# Plan-001: Makefile & CI/CD Improvements

**Based on**: [improvements-001.md](../research/improvements-001.md)
**Date**: 2026-03-06
**Scope**: All critical, high, medium, and low findings except C-3 (Renovate automerge — excluded per decision)

---

## Phase 1: Critical Fixes

### 1.1 C-1: Docker Container Smoke Test in CI (Option C)

Add a CI step that builds, runs, and health-checks the Docker container. This catches runtime crashes (like the missing `.env`) without changing the application code or Dockerfile `.env` handling.

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Add a `container-test` job after `image-scan` that:
  1. Builds the Docker image
  2. Runs it with `-e SERVER_PORT=8080`
  3. Polls `http://localhost:8080/` with a retry loop (up to 30s)
  4. Sends a test request to `POST /calculate`
  5. Fails the job if health check or API call fails
  6. Cleans up the container
- Add `make docker-test` Makefile target for local use (see Phase 4)

### 1.2 C-2: Create `.goreleaser.yml`

**Files**: `.goreleaser.yml` (new)
**Tasks**:
- Create GoReleaser config with:
  - Binary builds for `linux/amd64`, `linux/arm64`, `darwin/amd64`, `darwin/arm64`
  - Docker image publishing to GHCR
  - Changelog generation from conventional commits
  - Archive format: `tar.gz` (Linux), `zip` (macOS/Windows)
- Verify with `goreleaser check`

---

## Phase 2: High Severity Fixes

### 2.1 H-1: Reduce CI Workflow Permissions

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Change workflow-level permissions to `contents: read`
- Add per-job write permissions only where needed (e.g., `image-scan` if pushing)

### 2.2 H-2: Add Test Coverage Measurement and Enforcement

**Files**: `Makefile`, `.github/workflows/ci.yml`
**Tasks**:
- Wire up the existing `COVPROF` variable in new `coverage` and `coverage-check` targets
- `coverage`: run tests with `-coverprofile`, generate HTML report
- `coverage-check`: parse total coverage, fail if below 80%
- Add `coverage` job to CI pipeline (parallel with `tests`)

### 2.3 H-3: Fix Go Version Skew

**Files**: `.github/workflows/release.yml`, `Dockerfile`
**Tasks**:
- Change `release.yml` to use `go-version-file: 'go.mod'` instead of hardcoded `1.26.1`
- Pin Dockerfile `FROM golang` to match `go.mod` version exactly

### 2.4 H-4: Fix CMD/ENTRYPOINT Conflict

**Files**: `Dockerfile`
**Tasks**:
- Remove the `CMD` line
- Keep `ENTRYPOINT ["/main"]` with absolute path

### 2.5 H-5: Replace `sleep 6s` with Health-Check Poll Loop

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Replace both `sleep 6s` occurrences (integration and dast jobs) with:
  ```bash
  for i in $(seq 1 30); do
    curl -sf http://localhost:8080/ >/dev/null 2>&1 && break
    sleep 1
  done
  ```

### 2.6 H-6: Create `.dockerignore`

**Files**: `.dockerignore` (new)
**Tasks**:
- Exclude: `.git`, `.github`, `.zap`, `benchmarks`, `docs`, `specs`, `test`, `scripts`, `*.md`, `.golangci.yml`, `renovate.json`, `Makefile`, `.env`

### 2.7 H-7: Pin golangci-lint Version

**Files**: `Makefile`
**Tasks**:
- Change `curl | sh` to pin a specific version: `sh -s -- -b $(go env GOPATH)/bin v2.1.6`

### 2.8 H-8: Pin All Dev Tool Versions

**Files**: `Makefile`
**Tasks**:
- Replace `@latest` with pinned versions for: `swag`, `gosec`, `govulncheck`, `gitleaks`, `actionlint`, `benchstat`
- Determine current latest stable version for each tool and pin it

### 2.9 H-9: Fix `--load` + Multi-Platform Conflict

**Files**: `scripts/build-image.sh`
**Tasks**:
- Remove `--load` flag when `--push` is present
- Or conditionally apply `--load` only for single-platform builds

### 2.10 H-10: Fix Hardcoded macOS Cache Paths

**Files**: `scripts/build-image.sh`
**Tasks**:
- Replace hardcoded paths with dynamic detection:
  ```bash
  GOCACHE=${GOCACHE:-$(go env GOCACHE)}
  GOMODCACHE=${GOMODCACHE:-$(go env GOMODCACHE)}
  ```

### 2.11 H-11: Add HEALTHCHECK to Dockerfile

**Files**: `Dockerfile`
**Tasks**:
- Add `HEALTHCHECK` instruction using `wget` (available in Alpine):
  ```dockerfile
  HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1
  ```

### 2.12 H-12: Fix Release Workflow Name

**Files**: `.github/workflows/release.yml`
**Tasks**:
- Change `name: threeport-rest-api Release` to `name: flight-path Release`

### 2.13 H-13: Add Semver Validation to `make release`

**Files**: `Makefile`
**Tasks**:
- Add validation before git operations:
  ```makefile
  @echo "$(NT)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: Tag must match vN.N.N"; exit 1; }
  ```

---

## Phase 3: Medium Severity Fixes

### 3.1 M-1: Scope `git add` in Release Target

**Files**: `Makefile`
**Tasks**:
- Change `git add -A` to `git add pkg/api/version.txt`

### 3.2 M-2: Run `tests` Parallel with `builds`

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Change `tests` job dependency from `[builds]` to `[static-check]`
- Both `tests` and `builds` run in parallel after `static-check`

### 3.3 M-3: Eliminate Redundant Builds in CI

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Upload build artifact from `builds` job
- Download in `integration` and `dast` jobs instead of rebuilding from source

### 3.4 M-4: Deduplicate Trivy Installation

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Replace inline Trivy install + run with `aquasecurity/trivy-action` in both jobs

### 3.5 M-5: Add Non-Blocking MEDIUM Severity Trivy Scan

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Add MEDIUM severity scan with `--exit-code 0` for visibility (non-blocking)

### 3.6 M-6: Use `make static-check` in CI

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Replace individual lint/sec/vulncheck/secrets commands with `make static-check`

### 3.7 M-7: Align Docker Build Commands

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Use `make build-image` in `image-scan` job or document why the commands differ

### 3.8 M-8: Remove Single-Entry Strategy Matrix

**Files**: `.github/workflows/ci.yml`
**Tasks**:
- Remove `strategy.matrix` where it has only a single entry — simplify to direct values

### 3.9 M-9: Make GOOS/GOARCH Overridable

**Files**: `Makefile`
**Tasks**:
- Change `GOOS=linux GOARCH=amd64` to `GOOS ?= linux` and `GOARCH ?= amd64`

### 3.10 M-10: Make GOFLAGS Overridable

**Files**: `Makefile`
**Tasks**:
- Change `GOFLAGS=` to `GOFLAGS ?= -mod=mod`

### 3.11 M-11: Add `.PHONY` Declarations

**Files**: `Makefile`
**Tasks**:
- Add `.PHONY` for all targets (or a single `.PHONY` line listing all targets)

### 3.12 M-12: Add Default ARG Values in Dockerfile

**Files**: `Dockerfile`
**Tasks**:
- Add defaults: `ARG GOMODCACHE=/go/pkg/mod` and `ARG GOCACHE=/root/.cache/go-build`

### 3.13 M-13: Add Quality Gates to `make release`

**Files**: `Makefile`
**Tasks**:
- Add `test lint sec vulncheck` as dependencies of the `release` target

### 3.14 M-14: Add CI Gate Before Release

**Files**: `.github/workflows/release.yml`
**Tasks**:
- Add `workflow_run` trigger requiring CI to pass before release runs, or add manual approval step

### 3.15 M-15: Use Compiled Binary in `make run`

**Files**: `Makefile`
**Tasks**:
- Change `run` target to execute the compiled binary instead of `go run`

### 3.16 M-16: Make CORS Origin Configurable

**Files**: `main.go`
**Tasks**:
- Read allowed origins from environment variable (e.g., `CORS_ORIGIN`), default to `*` for dev

---

## Phase 4: Low Severity Fixes

### 4.1 L-1: Cross-Platform `open` Command

**Files**: `Makefile`
**Tasks**:
- Replace `xdg-open` with: `command -v xdg-open >/dev/null && xdg-open || open`

### 4.2 L-2: Remove No-Op `go generate`

**Files**: `Makefile`
**Tasks**:
- Remove `go generate` calls (no `//go:generate` directives exist)

### 4.3 L-3: Fix `run` Target Dependencies

**Files**: `Makefile`
**Tasks**:
- Change `run` dependency to `build` (which already includes `api-docs`)

### 4.4 L-4: Fix Typos

**Files**: `Makefile`
**Tasks**:
- Fix "currnet" -> "current" (line 2)
- Fix "statick" -> "static" (line 87)

### 4.5 L-5: Remove `@clear` from Help Target

**Files**: `Makefile`
**Tasks**:
- Remove `@clear` from the `help` target

### 4.6 L-6: Use `$(CURDIR)` Instead of `$(shell pwd)`

**Files**: `Makefile`
**Tasks**:
- Change `HOMEDIR=$(shell pwd)` to `HOMEDIR=$(CURDIR)`

### 4.7 L-7: Remove Premature G104 gosec Exclusion

**Files**: `.golangci.yml`
**Tasks**:
- Remove the G104 exclusion rule (no `.Close()` calls exist)

### 4.8 L-8: Add Version Tag to Docker Image

**Files**: `scripts/build-image.sh`
**Tasks**:
- Read version from `pkg/api/version.txt` and tag image with both `:latest` and `:<version>`

---

## Phase 5: New Makefile Targets

**Files**: `Makefile`
**Tasks**:
- Add `clean` — remove build artifacts, coverage files, test cache
- Add `coverage` — run tests with `-coverprofile`, generate HTML report
- Add `coverage-check` — fail if coverage < 80%
- Add `ci` — composite target mirroring CI: `static-check build test fuzz`
- Add `ci-full` — full pipeline: `ci coverage-check e2e`
- Add `check` — pre-commit checklist: `lint sec vulncheck secrets test api-docs build`
- Add `trivy-fs` — filesystem vulnerability scan
- Add `trivy-image` — image vulnerability scan
- Add `docker-build` — build image for local testing
- Add `docker-run` — run container locally
- Add `docker-test` — build and smoke-test container

---

## Implementation Order

| Order | Items | Rationale |
|-------|-------|-----------|
| 1 | C-1, C-2 | Critical — broken functionality |
| 2 | H-4, H-11, H-6, M-12 | Dockerfile fixes — batch together |
| 3 | H-1, H-3, H-5, H-12, M-2, M-3, M-4, M-5, M-6, M-7, M-8, M-14 | CI workflow fixes — batch together |
| 4 | H-2, H-7, H-8, H-13, M-1, M-9, M-10, M-11, M-13, M-15, Phase 4, Phase 5 | Makefile fixes — batch together |
| 5 | H-9, H-10, L-8 | Build script fixes |
| 6 | M-16 | Application code change (CORS) |
| 7 | L-7 | Linter config |

---

## Excluded

| ID | Finding | Reason |
|----|---------|--------|
| C-3 | Renovate automerges major updates | Excluded per decision |
