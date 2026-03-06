# Improvements-001: Makefile & GitHub CI/CD Workflow Review

**Issue**: [#179](https://github.com/AndriyKalashnykov/flight-path/issues/179)
**Date**: 2026-03-06
**Reviewed by**: builder, ci-validator, code-reviewer, devils-advocate, docker-ops, security-scanner, tech-architect agents (parallel execution)

## Executive Summary

Six specialized agents reviewed the project's Makefile and GitHub CI/CD workflows in parallel. The review uncovered **3 critical**, **13 high**, **16 medium**, and **8 low** severity findings. The most dangerous issue is that **every published Docker image crashes on startup** because `.env` is missing from the runtime stage and `godotenv.Load()` calls `log.Fatalf` — yet CI never runs the built container to catch this. The release workflow is also broken due to a missing `.goreleaser.yml` file.

---

## Table of Contents

1. [Critical Findings](#1-critical-findings)
2. [High Findings](#2-high-findings)
3. [Medium Findings](#3-medium-findings)
4. [Low Findings](#4-low-findings)
5. [CI-to-Makefile Mapping](#5-ci-to-makefile-mapping)
6. [Optimized CI Pipeline](#6-optimized-ci-pipeline)
7. [Missing Makefile Targets](#7-missing-makefile-targets)
8. [Cross-Platform Compatibility](#8-cross-platform-compatibility)
9. [Security Findings](#9-security-findings)
10. [Risk Register](#10-risk-register)

---

## 1. Critical Findings

### C-1: Docker Image Crashes at Runtime — CI Never Catches It

**Source**: docker-ops, devils-advocate
**Files**: `Dockerfile`, `main.go:44-47`

The `.env` file is never copied to the Docker runtime stage. `main.go` calls `log.Fatalf` when `godotenv.Load()` fails. Every built Docker image crashes immediately on startup. The CI `image-scan` job builds the image and scans it with Trivy but **never runs it**, so this crash goes undetected.

**Fix options**:
- **Option A**: Copy `.env` into runtime stage: `COPY --from=build /app/.env /`
- **Option B (preferred)**: Make `.env` loading optional — fall back to environment variables when the file is missing
- **Option C**: Add a CI step that runs the container and health-checks it

### C-2: Missing `.goreleaser.yml` — Release Workflow Is Broken

**Source**: ci-validator, tech-architect, devils-advocate
**File**: `.github/workflows/release.yml:34`

The release workflow passes `-f ./.goreleaser.yml` to GoReleaser, but this file does not exist in the repository. Every tag push fails the release job.

**Fix**: Create `.goreleaser.yml` with binary builds, Docker image publishing, and changelog generation from conventional commits.

### C-3: Renovate Automerges Major Version Updates

**Source**: devils-advocate
**File**: `renovate.json:23-28`

Renovate is configured to automerge `major`, `minor`, `patch`, `pin`, and `digest` update types with `platformAutomerge: true`. Combined with C-1 (Docker image never tested at runtime), a breaking major dependency bump can reach `main` with zero human review.

**Fix**: Exclude `major` from automerge: `"matchUpdateTypes": ["minor", "patch", "pin", "digest"]`.

---

## 2. High Findings

### H-1: CI Workflow Permissions Are Overly Broad

**Source**: security-scanner, devils-advocate
**File**: `.github/workflows/ci.yml:9-12`

The workflow declares `contents: write`, `packages: write`, `issues: write` at the workflow level. No CI job needs write access. This creates unnecessary privilege escalation risk, especially on `pull_request` events.

**Fix**: Change to `contents: read` at workflow level. Scope write permissions per-job only where needed.

### H-2: No Test Coverage Measurement or Enforcement

**Source**: ci-validator, tech-architect, builder, devils-advocate
**File**: `Makefile:8` (`COVPROF` defined but unused)

The project rules mandate 80% minimum coverage, but neither the Makefile nor CI measures or enforces it. The `COVPROF` variable is declared on line 8 but never used in any target.

**Fix**: Add `make coverage` target and a CI step that fails below 80%.

### H-3: Go Version Skew Across Workflows

**Source**: ci-validator, tech-architect, devils-advocate
**Files**: `ci.yml` (uses `go-version-file: 'go.mod'` → 1.26.0), `release.yml:21` (hardcodes `1.26.1`), `Dockerfile` (`golang:1.26-alpine`)

Three potentially different Go versions build the same code. The release binary may behave differently than what CI tested.

**Fix**: Use `go-version-file: 'go.mod'` consistently in all workflows. Pin the Dockerfile Go version to match.

### H-4: CMD + ENTRYPOINT Conflict in Dockerfile

**Source**: docker-ops, devils-advocate
**File**: `Dockerfile:32-33`

Both `CMD ["/bin/sh", "-c", "./main"]` and `ENTRYPOINT ["./main"]` are set. This effectively runs `./main /bin/sh -c ./main`. It works by accident because Go's `flag` package ignores extra non-flag arguments.

**Fix**: Remove the `CMD` line, keep only `ENTRYPOINT ["/main"]` with absolute path.

### H-5: `sleep 6s` for Server Readiness Is Fragile

**Source**: ci-validator, devils-advocate
**Files**: `.github/workflows/ci.yml:131,159`

Both `integration` and `dast` jobs use `sleep 6s` to wait for the server. If the server takes longer (slow CI runner) or crashes, the sleep completes and tests fail with misleading errors.

**Fix**: Replace with a polling loop:
```bash
for i in $(seq 1 30); do
  curl -sf http://localhost:8080/ >/dev/null 2>&1 && break
  sleep 1
done
```

### H-6: Missing `.dockerignore`

**Source**: docker-ops
**File**: Project root (missing)

Without `.dockerignore`, the entire repository (`.git/`, `benchmarks/`, `specs/`, `test/`, etc.) is sent as Docker build context, slowing builds and risking sensitive data exposure.

**Fix**: Create `.dockerignore` excluding `.git`, `.github`, `.zap`, `benchmarks`, `docs`, `specs`, `test`, `scripts`, `*.md`, `.golangci.yml`, `renovate.json`, `Makefile`.

### H-7: golangci-lint Installed via `curl | sh` (Supply Chain Risk)

**Source**: security-scanner
**File**: `Makefile:22`

`curl -sSfL https://golangci-lint.run/install.sh | sh` pipes a remote script into a shell without version pinning or checksum verification.

**Fix**: Pin version: `sh -s -- -b $(go env GOPATH)/bin v2.1.6`. Or use `go install` with a pinned version.

### H-8: All Dev Tools Installed at `@latest` (Unpinned)

**Source**: security-scanner, tech-architect, devils-advocate
**File**: `Makefile:19-25`

`swag@latest`, `gosec@latest`, `govulncheck@latest`, `gitleaks@latest`, `actionlint@latest`, `benchstat@latest` — non-reproducible builds and supply chain risk.

**Fix**: Pin all tools to specific versions. Consider a `tools.go` file to track versions in `go.mod`.

### H-9: `--load` + Multi-Platform Incompatible in `build-image.sh`

**Source**: docker-ops, builder
**File**: `scripts/build-image.sh:22`

`--load` only works for single-platform builds. Combined with `--platform linux/amd64,linux/arm64,linux/arm/v7` and `--push`, the build will fail or behave unexpectedly.

**Fix**: Remove `--load` when `--push` is present.

### H-10: Hardcoded macOS Cache Paths in `build-image.sh`

**Source**: docker-ops, builder, tech-architect
**File**: `scripts/build-image.sh:5-6`

`GOCACHE=${HOME}/Library/Caches/go-build` is macOS-specific. On Linux, the Go build cache is at `${HOME}/.cache/go-build`.

**Fix**: Use `go env GOCACHE` and `go env GOMODCACHE` dynamically:
```bash
GOCACHE=${GOCACHE:-$(go env GOCACHE)}
GOMODCACHE=${GOMODCACHE:-$(go env GOMODCACHE)}
```

### H-11: Missing HEALTHCHECK in Dockerfile

**Source**: docker-ops
**File**: `Dockerfile`

No `HEALTHCHECK` instruction. Container orchestrators can't determine container health.

**Fix**: Add:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1
```

### H-12: Release Workflow Name Is "threeport-rest-api Release"

**Source**: ci-validator, tech-architect
**File**: `.github/workflows/release.yml:1`

Copy-paste error from another project.

**Fix**: Rename to `flight-path Release`.

### H-13: Tag Injection Risk in `make release`

**Source**: security-scanner
**File**: `Makefile:106-113`

The `NEWTAG` variable is used unvalidated in `git commit`, `git tag`, and `git push` commands. Shell metacharacters in the tag value could execute arbitrary commands.

**Fix**: Add semver validation:
```makefile
@echo "$(NT)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: Tag must match vN.N.N"; exit 1; }
```

---

## 3. Medium Findings

| # | Finding | File | Fix |
|---|---------|------|-----|
| M-1 | `release` uses `git add -A` — risks staging secrets/artifacts | `Makefile:109` | Scope to `git add pkg/api/version.txt` |
| M-2 | `tests` job depends on `builds` but doesn't use the artifact | `ci.yml:69` | Run `tests` parallel with `builds` after `static-check` |
| M-3 | `integration` and `dast` rebuild from source (redundant) | `ci.yml:125,155` | Upload build artifact, download in downstream jobs |
| M-4 | Trivy installation duplicated across 2 CI jobs | `ci.yml:37-42,189-196` | Use `aquasecurity/trivy-action` or composite action |
| M-5 | Trivy MEDIUM severity excluded from scans | `ci.yml:45,198` | Add non-blocking MEDIUM scan (`--exit-code 0`) for visibility |
| M-6 | CI doesn't use `make static-check` composite target | `ci.yml:32-34` | Use `make static-check` for local-CI parity |
| M-7 | `image-scan` doesn't use `make build-image` | `ci.yml:183-187` | Align build commands or document difference |
| M-8 | Single-entry `strategy.matrix` adds complexity for no benefit | `ci.yml:72-73,98-100` | Remove matrix or add meaningful entries |
| M-9 | `build` target hardcodes `GOOS=linux GOARCH=amd64` | `Makefile:94` | Use `?=` for overridable GOOS/GOARCH |
| M-10 | `GOFLAGS` not overridable | `Makefile:3` | Change to `GOFLAGS ?= -mod=mod` |
| M-11 | No `.PHONY` declarations | `Makefile` | Add `.PHONY` for all targets |
| M-12 | BuildKit cache mount ARGs have no defaults | `Dockerfile:5` | Add `ARG GOMODCACHE=/go/pkg/mod` |
| M-13 | `make release` skips all quality gates | `Makefile:105` | Add `test lint sec vulncheck` as dependencies |
| M-14 | No CI gate before release (tag push triggers release immediately) | `release.yml` | Add `workflow_run` trigger or manual approval |
| M-15 | `run` target uses `go run` instead of compiled binary | `Makefile:98` | Use `./server -env-file .env` |
| M-16 | CORS allows all origins (`*`) | `main.go:56` | Make configurable via environment variable |

---

## 4. Low Findings

| # | Finding | File | Fix |
|---|---------|------|-----|
| L-1 | `xdg-open` is Linux-only | `Makefile:122` | Add macOS `open` fallback |
| L-2 | `go generate` calls are no-ops (no directives exist) | `Makefile:35,93` | Remove or add comment explaining placeholder |
| L-3 | `run` depends on `api-docs` twice | `Makefile:97` | Change to `run: build` |
| L-4 | Typos: "currnet" (line 2), "statick" (line 87) | `Makefile` | Fix spelling |
| L-5 | `help` target clears screen | `Makefile:12` | Remove `@clear` |
| L-6 | `HOMEDIR` uses `$(shell pwd)` instead of `$(CURDIR)` | `Makefile:7` | Use built-in `$(CURDIR)` |
| L-7 | G104 gosec exclusion for `.Close()` — no `.Close()` calls exist | `.golangci.yml:89-90` | Remove premature exclusion |
| L-8 | No version tag on Docker image (only `:latest`) | `scripts/build-image.sh` | Also tag with version from `pkg/api/version.txt` |

---

## 5. CI-to-Makefile Mapping

### CI Steps With Makefile Targets

| CI Job | CI Step | Makefile Target | Status |
|--------|---------|-----------------|--------|
| `static-check` | Lint, sec, vulncheck, secrets, lint-ci | `make deps lint sec vulncheck secrets lint-ci` | Direct match |
| `static-check` | Trivy filesystem scan | (none) | **GAP** |
| `builds` | Build | `make build` | Direct match |
| `tests` | Unit tests | `make test` | Direct match |
| `tests` | Fuzz tests | `make fuzz` | Direct match |
| `integration` | Run E2E tests | `make e2e` | Direct match |
| `integration` | Start server + wait | (none) | **GAP** |
| `dast` | OWASP ZAP scan | (none) | **GAP** |
| `image-scan` | Build Docker image | `make build-image` (partial) | **MISMATCH** |
| `image-scan` | Trivy image scan | (none) | **GAP** |
| `release` | GoReleaser | (none) | **BROKEN** |

### Makefile Targets Without CI Coverage

| Makefile Target | Purpose | Should CI Run It? |
|-----------------|---------|-------------------|
| `bench` / `bench-save` / `bench-compare` | Benchmarks | Yes — regression detection |
| `build-image` | Docker build | Yes — but CI uses inline commands |
| `static-check` | Composite lint/sec/vuln | Yes — CI should use this target |
| `update` | Dependency update | No — manual only |
| `open-swagger` | Browser open | No — interactive only |
| `test-case-*` | Manual curl tests | No — interactive only |

---

## 6. Optimized CI Pipeline

### Current Pipeline (Sequential)

```
static-check → builds → tests → integration → dast
                   └──→ image-scan
```

**Critical path**: 5 sequential jobs (~15-20 min)

### Proposed Pipeline (Parallel Where Possible)

```
static-check
    ├── builds ──→ image-scan
    ├── tests ──→ integration
    │            └──→ dast
    └── coverage (new)
```

**Changes**:
- `tests` runs parallel with `builds` (tests don't need the binary)
- `integration` and `dast` can run in parallel (both need server, independent concerns)
- Add `coverage` job parallel with others
- Upload build artifact from `builds`, download in `integration`/`dast` (eliminate 2 redundant builds)

**Estimated savings**: ~3-5 minutes off critical path.

---

## 7. Missing Makefile Targets

### Recommended Additions

```makefile
#clean: @ Remove build artifacts
clean:
	@rm -f server
	@rm -rf $(OUTDIR)
	@rm -f $(COVPROF)
	@go clean -testcache

#coverage: @ Run tests with coverage report
coverage:
	@mkdir -p $(OUTDIR)
	@go test -coverprofile=$(COVPROF) -covermode=atomic ./...
	@go tool cover -func=$(COVPROF)
	@go tool cover -html=$(COVPROF) -o $(OUTDIR)/coverage.html

#coverage-check: @ Verify coverage meets 80% threshold
coverage-check: coverage
	@TOTAL=$$(go tool cover -func=$(COVPROF) | grep total | awk '{print $$3}' | tr -d '%'); \
	echo "Coverage: $${TOTAL}%"; \
	if [ "$$(echo "$${TOTAL} < 80" | bc -l)" -eq 1 ]; then \
		echo "FAIL: Coverage $${TOTAL}% is below 80% threshold"; exit 1; \
	else \
		echo "PASS: Coverage meets 80% threshold"; \
	fi

#ci: @ Run full CI pipeline locally (mirrors GitHub Actions)
ci: static-check build test fuzz
	@echo "Local CI pipeline passed."

#ci-full: @ Run full CI pipeline including E2E and Docker
ci-full: ci coverage-check e2e-local
	@echo "Full CI pipeline passed."

#check: @ Run pre-commit checklist
check: lint sec vulncheck secrets test api-docs build
	@echo "All pre-commit checks passed."

#trivy-fs: @ Run Trivy filesystem vulnerability scan
trivy-fs:
	trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH --exit-code 1 .

#trivy-image: @ Run Trivy image vulnerability scan
trivy-image:
	trivy image --severity CRITICAL,HIGH --exit-code 1 flight-path:scan

#docker-build: @ Build Docker image for local testing
docker-build:
	docker buildx build --load \
		--build-arg GOMODCACHE=$$(go env GOMODCACHE) \
		--build-arg GOCACHE=$$(go env GOCACHE) \
		-t flight-path:local .

#docker-run: @ Run Docker container locally
docker-run: docker-build
	docker run --rm -p 8080:8080 -e SERVER_PORT=8080 flight-path:local

#docker-test: @ Build and smoke-test Docker container
docker-test: docker-build
	@docker run -d --name fp-test -p 8080:8080 -e SERVER_PORT=8080 flight-path:local; \
	for i in $$(seq 1 10); do curl -sf http://localhost:8080/ >/dev/null 2>&1 && break; sleep 1; done; \
	curl -sf http://localhost:8080/ && echo "Health: OK" || echo "Health: FAIL"; \
	curl -sf -X POST http://localhost:8080/calculate \
		-H 'Content-Type: application/json' \
		-d '[["SFO","ATL"],["ATL","EWR"]]' && echo " API: OK" || echo "API: FAIL"; \
	docker stop fp-test && docker rm fp-test
```

---

## 8. Cross-Platform Compatibility

| Issue | File | Linux | macOS | Fix |
|-------|------|-------|-------|-----|
| `xdg-open` | `Makefile:122` | Works | Fails | `command -v xdg-open \|\| command -v open` |
| `GOOS=linux` in build | `Makefile:94` | Native | Cross-compiles | Use `?=` for GOOS/GOARCH |
| macOS `GOCACHE` path | `build-image.sh:5` | Wrong path | Correct | Use `$(go env GOCACHE)` |
| `nvm` in `make deps` | `Makefile:26` | Depends on install | Depends on install | Document prerequisite or add fallback |
| `clear` in help | `Makefile:12` | Works | Works | Remove (destroys terminal history) |
| `date +%Y%m%d_%H%M%S` | `Makefile:49` | Works | Works | OK |
| `seq` in scripts | Various | Works | Works (since macOS 12) | OK |
| GNU Make features | `Makefile` | Works | Works (with `brew install make`) | Document GNU Make requirement |

---

## 9. Security Findings

### By Severity

| ID | Severity | Finding | File |
|----|----------|---------|------|
| S-01 | HIGH | CI permissions overly broad (`contents: write` on all jobs) | `ci.yml:9-12` |
| S-06 | HIGH | golangci-lint installed via `curl \| sh` (supply chain) | `Makefile:22` |
| S-12 | HIGH | Tag injection via unvalidated `NEWTAG` in release target | `Makefile:106-113` |
| S-02 | MEDIUM | Release workflow missing explicit permissions block | `release.yml` |
| S-04 | MEDIUM | Custom PAT (`GH_ACCESS_TOKEN`) used for GHCR — scope unknown | `release.yml:28` |
| S-07 | MEDIUM | All `go install` commands use `@latest` (unpinned) | `Makefile:19-25` |
| S-11 | MEDIUM | Trivy excludes MEDIUM severity findings | `ci.yml:45,198` |
| S-14 | MEDIUM | CORS allows all origins (`*`) | `main.go:55-57` |
| S-17 | MEDIUM | CI triggers on all push events (no branch restriction) | `ci.yml:6-7` |
| S-03 | INFO+ | All GitHub Actions pinned to SHA | `ci.yml`, `release.yml` |
| S-05 | INFO+ | Secrets not interpolated in shell commands | `ci.yml`, `release.yml` |

### ZAP Rule Suppressions (`.zap/rules.tsv`)

| Rule ID | Name | Verdict |
|---------|------|---------|
| 100001 | Unexpected Content-Type | Acceptable — Swagger UI serves HTML |
| 100000 | Client/Server Error Codes | Acceptable — expected during fuzzing |
| 10023 | Info Disclosure - Debug Errors | Acceptable with caveat — verify API responses don't leak traces |
| 10049 | Non-Storable Content | Acceptable — intentional `Cache-Control: no-store` |
| 90022 | Application Error Disclosure | Acceptable with caveat — re-test if error handling changes |

---

## 10. Risk Register

| # | Risk | Severity | Likelihood | Impact | Mitigation |
|---|------|----------|------------|--------|------------|
| C-1 | Docker image crashes at runtime | CRITICAL | Certain | Every published image is broken | Make `.env` optional or add container smoke test to CI |
| C-2 | Missing `.goreleaser.yml` | CRITICAL | Certain | Release workflow always fails | Create goreleaser config |
| C-3 | Renovate automerges majors | CRITICAL | Medium | Breaking changes auto-merged | Exclude `major` from automerge |
| H-1 | CI permissions too broad | HIGH | Low (exploit) | Privilege escalation on PRs | Reduce to `contents: read` |
| H-2 | No coverage enforcement | HIGH | Certain | Coverage degrades over time | Add `make coverage-check` + CI step |
| H-3 | Go version skew | HIGH | Medium | Release differs from tested | Use `go-version-file` everywhere |
| H-4 | CMD/ENTRYPOINT conflict | HIGH | Certain | Unexpected container arguments | Remove `CMD` line |
| H-5 | `sleep 6s` fragile | HIGH | Medium | Flaky CI, misleading failures | Replace with health-check poll loop |
| H-6 | Missing `.dockerignore` | HIGH | Certain | Slow builds, data exposure risk | Create `.dockerignore` |
| H-7 | `curl \| sh` supply chain | HIGH | Low | RCE via compromised script | Pin version or use `go install` |
| H-8 | Tools at `@latest` | HIGH | High | Non-reproducible builds | Pin all tool versions |
| H-9 | `--load` + multi-platform | HIGH | Certain | Build script fails on multi-platform | Remove `--load` when `--push` |
| H-10 | macOS cache paths | HIGH | Certain (Linux) | No cache benefit on Linux | Use `go env` dynamically |
| H-11 | No HEALTHCHECK | HIGH | Certain | Orchestrators can't check health | Add `HEALTHCHECK` instruction |
| H-12 | Wrong release workflow name | HIGH | Certain | Confusing GitHub Actions UI | Rename to "flight-path Release" |
| H-13 | Tag injection in release | HIGH | Low | Command injection via tag value | Add semver validation |
| M-1 | `git add -A` in release | MEDIUM | Medium | Accidentally stage secrets | Scope to specific files |
| M-2 | Artificial `tests→builds` dep | MEDIUM | Certain | +2-3 min CI time | Run in parallel after `static-check` |
| M-3 | Redundant builds in CI | MEDIUM | Certain | Wasted CI minutes | Upload/download build artifacts |
| M-4 | Trivy install duplicated | MEDIUM | Certain | Maintenance burden | Use `aquasecurity/trivy-action` |
| M-13 | `make release` skips tests | MEDIUM | Medium | Bad release published | Add quality gate dependencies |

---

## Appendix: Agent Coverage

| Agent | Focus Area | Key Contributions |
|-------|-----------|-------------------|
| **ci-validator** | CI-Makefile parity, job ordering | Mapping table, gap analysis, pipeline optimization |
| **security-scanner** | Permissions, supply chain, secrets | 17 security findings with remediation |
| **docker-ops** | Dockerfile, image build, scanning | 13 Docker findings including 2 critical |
| **tech-architect** | Architecture, DRY, environment consistency | Pipeline redesign, composite actions, coverage enforcement |
| **builder** | Makefile targets, dependencies, portability | Missing targets, cross-platform issues, error handling |
| **devils-advocate** | Risk assessment, false confidence, edge cases | 19 risks ranked, Renovate automerge discovery, strongest-argument summary |
