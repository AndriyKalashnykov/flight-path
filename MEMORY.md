---
description: Project-specific context and knowledge base
---

# Project Memory

## Current Version
- `pkg/api/version.txt`: v0.0.3

## Architecture Notes

- `FindItinerary()` in `api.go` uses plain maps for source/destination tracking — O(n) time and space
- `Handler` struct is empty (`type Handler struct{}`), DI-ready but no dependencies injected yet
- Middleware: RequestLogger, Recover, CORS (configurable via `CORS_ORIGIN` env var, defaults to `"*"`), Secure headers

## Known Tech Debt

- **Test data in public package**: `TestFlights` (19 segments) lives in `pkg/api/data.go` — should move to `internal/` or `_test.go`
- **CORS wildcard**: `main.go` defaults to `"*"` for allowed origins when `CORS_ORIGIN` is unset

## CI Pipeline

- Three workflows: `ci.yml` (static-check → builds/tests → integration/dast/image-scan/container-test), `release.yml` (goreleaser on tags via workflow_call), `cleanup-runs.yml` (weekly cleanup)
- Renovate auto-merges all dependency updates with `chore(all):` prefix
