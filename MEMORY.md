---
description: Project-specific context and knowledge base
---

# Project Memory

## Current Version
- `pkg/api/version.txt`: v0.0.3

## Architecture Notes

- `FindItinerary()` in `api.go` uses `sync.Map` for source/destination tracking — unusual for a non-concurrent algorithm, potential simplification target
- `FindItineraryOptimized()` exists only in `api_bench_test.go` — uses plain maps, O(n), not used in production
- `Handler` struct is empty (`type Handler struct{}`), DI-ready but no dependencies injected yet
- Middleware: RequestLogger, Recover, CORS (currently allows `"*"` — restrict for production)

## Known Tech Debt

- **No unit tests**: Only benchmark tests exist in `api_bench_test.go`. Testing rules describe extensive patterns but none are implemented yet
- **Test data in public package**: `TestFlights` (19 segments) lives in `pkg/api/data.go` — should move to `internal/` or `_test.go`
- **Missing `.goreleaser.yml`**: Release workflow in `.github/workflows/release.yml` references it but the file doesn't exist
- **CORS wildcard**: `main.go` uses `"*"` for allowed origins

## CI Pipeline

- Two workflows: `ci.yml` (lint → build → test → e2e) and `release.yml` (goreleaser on tags)
- Renovate auto-merges all dependency updates with `chore(all):` prefix
