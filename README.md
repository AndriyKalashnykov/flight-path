[![CI](https://github.com/AndriyKalashnykov/flight-path/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/flight-path/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/flight-path.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/flight-path/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/flight-path)

# Flight Path

A Go REST API microservice that calculates flight paths from unordered flight segments. Given a list of [source, destination] pairs, it determines the complete path (starting airport to ending airport). Built with Go 1.26.1 + Echo v5 + Swagger/Swaggo.

## Quick Start

```bash
make deps      # install dev tools (golangci-lint, gosec, swag, etc.)
make build     # generate Swagger docs + compile binary
make test      # run unit + handler tests
make run       # build and start the server on http://localhost:8080
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Go](https://go.dev/dl/) | 1.26.1+ (from `go.mod`) | Language runtime and compiler |
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Git](https://git-scm.com/) | 2.0+ | Version control |
| [Docker](https://www.docker.com/) | latest | Container builds and testing |
| [Node.js](https://nodejs.org/) | 24 | Newman E2E tests *(installed via nvm by `make deps`)* |

Install all required dev tools:

```bash
make deps
```

## Available Make Targets

Run `make help` to see all available targets.

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build REST API server's binary |
| `make run` | Run REST API locally |
| `make api-docs` | Build source code for swagger api reference |
| `make clean` | Remove build artifacts and test cache |
| `make update` | Update dependencies to latest versions |

### Testing

| Target | Description |
|--------|-------------|
| `make test` | Run tests |
| `make fuzz` | Run fuzz tests for 30 seconds |
| `make bench` | Run bench tests |
| `make bench-save` | Save benchmark results to file |
| `make bench-compare` | Compare two benchmark files (usage: `make bench-compare OLD=file1.txt NEW=file2.txt`) |
| `make coverage` | Run tests with coverage report |
| `make coverage-check` | Verify coverage meets 80% threshold |
| `make e2e` | Run Postman/Newman end-to-end tests |

### Code Quality

| Target | Description |
|--------|-------------|
| `make format` | Format Go code |
| `make lint` | Run golangci-lint and hadolint (60+ linters via .golangci.yml) |
| `make sec` | Run gosec security scanner |
| `make vulncheck` | Run Go vulnerability check on dependencies |
| `make secrets` | Scan for hardcoded secrets in source code and git history |
| `make lint-ci` | Lint GitHub Actions workflow files |
| `make static-check` | Run code static check |

### Docker

| Target | Description |
|--------|-------------|
| `make docker-build` | Build Docker image for local testing |
| `make docker-run` | Run Docker container locally |
| `make docker-test` | Build and smoke-test Docker container |
| `make docker-scan` | Build Docker image and run Trivy scan (requires trivy) |
| `make image-build` | Build Docker image (full checks + test) |
| `make trivy-fs` | Run Trivy filesystem vulnerability scan (requires trivy) |
| `make trivy-image` | Run Trivy image vulnerability scan (requires trivy) |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full CI pipeline locally (deps + format + static-check + test + coverage-check + fuzz + build) |
| `make ci-full` | Run full CI pipeline including coverage (format + static-check + coverage-check + fuzz + build) |
| `make ci-run` | Run GitHub Actions workflow locally using [act](https://github.com/nektos/act) |
| `make check` | Run pre-commit checklist (format + static-check + test + build) |

### Utilities

| Target | Description |
|--------|-------------|
| `make help` | List available tasks |
| `make deps` | Download and install dependencies |
| `make deps-check` | Show required Go version and tool status |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-act` | Install act for running GitHub Actions locally |
| `make deps-trivy` | Install trivy for local vulnerability scanning |
| `make deps-renovate` | Install nvm and pnpm for Renovate |
| `make release` | Create and push a new tag |
| `make open-swagger` | Open browser with Swagger docs pointing to localhost |
| `make renovate-validate` | Validate Renovate configuration |
| `make deps-prune` | Remove unused Go module dependencies |
| `make deps-prune-check` | Verify no prunable dependencies (CI gate) |
| `make test-case-one` | Test case #1 `[["SFO", "EWR"]]` |
| `make test-case-two` | Test case #2 `[["ATL", "EWR"], ["SFO", "ATL"]]` |
| `make test-case-three` | Test case #3 `[["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]` |

## Architecture

See [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for C4 diagrams (Context, Container, Component), request flow sequence diagram, and CI/CD pipeline flowchart.

## Security & Code Quality

### SAST (Static Application Security Testing)

| Tool | Command | What it does |
|------|---------|-------------|
| [gosec](https://github.com/securego/gosec) | `make sec` | Go-specific security scanner (injection, crypto, permissions) |
| [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) | `make vulncheck` | Checks dependencies against the Go vulnerability database |
| [gitleaks](https://github.com/gitleaks/gitleaks) | `make secrets` | Scans source code and git history for hardcoded secrets |

### DAST (Dynamic Application Security Testing)

| Tool | Where | What it does |
|------|-------|-------------|
| [OWASP ZAP](https://github.com/zaproxy/zaproxy) | CI only | API security scan using Swagger/OpenAPI spec |

### Linting

| Tool | Command | What it does |
|------|---------|-------------|
| [golangci-lint](https://github.com/golangci/golangci-lint) | `make lint` | Meta-linter running 60+ linters (configured via `.golangci.yml`) |
| [hadolint](https://github.com/hadolint/hadolint) | `make lint` | Dockerfile linter |
| [actionlint](https://github.com/rhysd/actionlint) | `make lint-ci` | Lints GitHub Actions workflow files |

### Container Security

| Tool | Where | What it does |
|------|-------|-------------|
| [Trivy](https://github.com/aquasecurity/trivy) | CI + local (`make trivy-fs`, `make docker-scan`) | Scans Docker images and filesystem for CVEs |

### Testing

| Tool | Command | What it does |
|------|---------|-------------|
| go test | `make test` | Unit and handler tests (table-driven) |
| go test -bench | `make bench` | Benchmark tests for critical paths |
| go test -fuzz | `make fuzz` | Fuzz testing for FindItinerary algorithm |
| [Newman](https://github.com/postmanlabs/newman) | `make e2e` | Postman/Newman end-to-end API tests |

## API

- **POST /calculate** — accepts `[][]string` flight segments, returns `[]string` (start and end airports)
- **GET /** — health check
- **GET /swagger/*** — Swagger UI ([http://localhost:8080/swagger/index.html](http://localhost:8080/swagger/index.html))

Auto-generated OpenAPI spec: [`docs/swagger.json`](./docs/swagger.json)

![Swagger API documentation](./img/swagger-api-doc.jpg)

## CI/CD

GitHub Actions runs on every push to `main`, tags `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **static-check** | push, PR, tags | golangci-lint, gosec, govulncheck, gitleaks, actionlint, Trivy filesystem scan |
| **builds** | after static-check | Build binary, upload artifact |
| **tests** | after static-check | Coverage threshold check (80%+), fuzz tests |
| **integration** | after builds + tests | Download binary, run server, Newman/Postman E2E tests |
| **dast** | after builds + tests | Run server, OWASP ZAP API security scan |
| **image-scan** | after builds | Build Docker image, Trivy vulnerability scan |
| **container-test** | after image-scan | Load Docker image, health-check, API smoke test |

| Job | Triggers | Steps |
|-----|----------|-------|
| **goreleaser** | after ci | GoReleaser build, GitHub release, push container images |

The [release workflow](./.github/workflows/release.yml) runs on tag pushes (`v*.*.*`), calling ci.yml via `workflow_call` for full CI validation, then executing GoReleaser.

A [cleanup workflow](./.github/workflows/cleanup-runs.yml) runs weekly (Sundays at 00:00 UTC) to delete old workflow runs (retain 7 days, keep minimum 5).

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.

## Postman/Newman end-to-end tests

Utilized Postman collection exported to [JSON file](./test/FlightPath.postman_collection.json)
and executes same use cases as Makefile targets `test-case-one` `test-case-two` `test-case-three`, plus negative test cases (empty body, malformed JSON, incomplete segment).

Uses hybrid validation: Ajv JSON Schema validation for response structure (global schemas defined at collection level) and Chai assertions for exact business values

![Postman/Newman end-to-end tests](./img/postman-newman.jpg)
