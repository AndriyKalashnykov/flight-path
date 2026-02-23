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

1. `make bench-save` (baseline)
2. Implement optimization
3. `make bench-save` (after)
4. `make bench-compare`
5. `make test` (verify correctness)

## Release

1. Ensure clean main branch
2. Run full checks: `make lint && make critic && make sec && make test && make build`
3. Update `pkg/api/version.txt`
4. `make release` (creates tag and pushes)

## Docker

```bash
docker build -t flight-path:local .           # Build locally
docker run -d -p 8080:8080 flight-path:local  # Run
make test-case-one                             # Smoke test
make build-image                               # Multi-platform push
```

Image: multi-stage Alpine build, non-root user (srvuser:1000), CGO_ENABLED=0, platforms: amd64/arm64/arm-v7.

## CI Pipeline (GitHub Actions)

1. **static-check**: `make deps lint critic sec`
2. **builds**: `make build`
3. **tests**: `make test`
4. **integration**: start server, `make e2e`

Release workflow triggers on git tags via GoReleaser.

## Dependency Updates

- Renovate auto-creates and auto-merges PRs
- Manual: `make update` (runs `go get -u && go mod tidy`)
