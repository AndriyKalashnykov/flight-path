---
name: environment
description: >
  Development environment setup, tool locations, and dependency installation for the flight-path Go project.
  Use when setting up the project, installing tools, troubleshooting PATH issues, or asking about Go/Node versions.
  Do NOT use for runtime troubleshooting, workflow guidance, or CI pipeline questions.
---

# Development Environment

## Go (via mise)

Pinned in `.mise.toml` at repo root: `go = "1.26.4"`. Activated automatically via shell hook (`eval "$(mise activate bash)"` or zsh/fish equivalent in `~/.zshrc`). `make deps` installs the pinned Go through mise; CI installs it the same way via `jdx/mise-action` (which reads `.mise.toml`, mirrored from `go.mod`) — not `actions/setup-go`.

## Node.js (via nvm)

Required for Newman E2E tests. Installed by `make deps` if not present.

## Tool Installation

`make deps` installs all tools idempotently (skips if already present):

| Tool | Version | Purpose |
|---|---|---|
| `swag` | v1.16.6 | Swagger doc generation |
| `gosec` | v2.24.0 | Security scanner |
| `govulncheck` | v1.1.4 | Dependency vulnerability check |
| `gitleaks` | v8.24.0 | Secrets detection |
| `actionlint` | v1.7.7 | GitHub Actions linter |
| `benchstat` | latest | Benchmark comparison |
| `golangci-lint` | v2.11.1 | Meta-linter (60+ linters) |
| `node` | LTS (via nvm) | Newman runtime |
| `newman` | latest (via npm) | E2E API testing |

Most build targets depend on `deps` and auto-install missing tools.

## Makefile Targets

| Target | Depends on | What it does |
|---|---|---|
| `deps` | — | Install all tools |
| `lint` | deps | golangci-lint |
| `sec` | deps | gosec security scan |
| `vulncheck` | deps | govulncheck |
| `secrets` | deps | gitleaks scan |
| `lint-ci` | deps | actionlint |
| `static-check` | deps, lint, sec, vulncheck, secrets, lint-ci | All static checks |
| `api-docs` | deps | Swagger generation |
| `test` | — | Unit tests (`go test -v ./...`) |
| `fuzz` | — | Fuzz tests (30s) |
| `bench` | — | Benchmarks |
| `bench-save` | deps | Save benchmark with timestamp |
| `bench-compare` | deps | Compare latest two benchmarks |
| `build` | api-docs | Compile binary |
| `run` | build | Build and start server |
| `check` | ci | Alias for `make ci` (full local pipeline) |
| `ci` | deps, static-check, test, integration-test, coverage, coverage-check, build, fuzz, deps-prune-check | Local CI pipeline |
| `ci-run` | deps | Run the GitHub Actions workflow locally via act |
| `coverage` | — | Test coverage report |
| `coverage-check` | coverage | Verify 80% threshold |
| `clean` | — | Remove build artifacts and test cache |
| `image-build` | build | Build Docker image locally (`flight-path:local`) |
| `image-run` | image-stop, image-build | Run container locally (detached) |
| `image-stop` | — | Stop the locally running container |
| `image-push` | image-build | Push Docker image to GHCR |
| `image-smoke-test` | — | Smoke-test a pre-built container |
| `image-structure-test` | — | Validate image metadata + binary (container-structure-test) |
| `image-test` | image-build, image-smoke-test, image-structure-test | Build + smoke-test + structure-test |
| `image-scan` | deps, build | Build image + Trivy scan (trivy installed via mise) |
| `release` | ci | Tag and push release (runs full `ci` first) |
| `e2e` | deps | Newman E2E tests |
| `update` | — | Update Go dependencies |

## If Tools Not Found

Ensure `$(go env GOPATH)/bin` is in PATH:
```bash
export PATH=$PATH:$(go env GOPATH)/bin
```
