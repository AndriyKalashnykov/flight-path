---
description: Project-specific development workflows
---

# Development Workflows

## Adding a New Endpoint

1. Create handler method on `Handler` struct in `internal/handlers/` with Swagger annotations
2. Register route in `internal/routes/` (receives `*handlers.Handler`)
3. Wire route in `main.go`
4. Run `make api-docs`
5. Write table-driven tests
6. Add Postman test case to `test/FlightPath.postman_collection.json`
7. Run: `make test && make build`

## Performance Optimization

1. `make bench-save` (baseline — saved to `benchmarks/bench_YYYYMMDD_HHMMSS.txt`)
2. Implement optimization
3. `make bench-save` (after)
4. `make bench-compare` (auto-picks latest two files, or specify `OLD=file1 NEW=file2`)
5. `make test` (verify correctness)

Benchmarks run: `go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s`

## Pre-commit Checklist

```bash
make lint           # golangci-lint
make critic         # gocritic (installs it first)
make sec            # gosec security scanner
make test           # Unit/bench tests
make api-docs       # Regenerate Swagger docs
make build          # Full build (runs all of the above + compile)
```

`make build` is the all-in-one target — it depends on: `deps lint critic sec api-docs`.

## Release

1. Ensure clean main branch, all checks pass
2. Run full checks: `make build` (covers lint, critic, sec, api-docs)
3. `make release` — prompts for new tag, updates `pkg/api/version.txt`, commits, tags, and pushes
4. GitHub Actions release workflow triggers on tag push (uses GoReleaser)

## Docker

```bash
docker build -t flight-path:local .           # Build locally (single platform)
docker run -d -p 8080:8080 flight-path:local  # Run container
make test-case-one                             # Smoke test
make build-image                               # Multi-platform build + push to Docker Hub
```

- Image: multi-stage Alpine build (`golang:1.26-alpine` -> `alpine:3.23.3`)
- Non-root user: `srvuser:1000`, `CGO_ENABLED=0`
- Platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`
- Registry: `andriykalashnykov/flight-path:latest` on Docker Hub
- `make build-image` runs checks first (`deps api-docs lint critic sec`) then calls `scripts/build-image.sh`

## CI Pipeline (GitHub Actions)

Pipeline in `.github/workflows/ci.yml`, runs on push and PRs:

| Job | Depends on | What it runs |
|---|---|---|
| `static-check` | — | `make deps lint critic sec` |
| `builds` | static-check | `make build` |
| `tests` | builds | `make test` |
| `integration` | builds, tests | Start server, install Newman, `make e2e` |

- Go version read from `go.mod` via `actions/setup-go`
- Integration job sets up Node.js for Newman
- Release workflow (`.github/workflows/release.yml`) triggers on git tags via GoReleaser

## Dependency Updates

- **Automated**: Renovate auto-creates and auto-merges PRs (config: `renovate.json`)
- **Manual**: `make update` (runs `go get -u && go mod tidy`)

## Quick Test Commands

```bash
make test-case-one    # Single flight: [["SFO", "EWR"]]
make test-case-two    # Two flights: [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three  # Four flights: [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
make open-swagger     # Open Swagger UI in browser
```
