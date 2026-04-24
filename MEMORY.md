---
description: Project-specific context and knowledge base
---

# Project Memory

## Current Version
- `pkg/api/version.txt`: v0.0.3

## Architecture Notes

- `FindItinerary()` in `internal/handlers/api.go` uses plain maps for source/destination tracking — O(n) time and space
- `Handler` struct is empty (`type Handler struct{}`), DI-ready but no dependencies injected yet
- Echo bootstrap lives in `internal/app/` (`New()` + `Port()`), shared by `main.go` and integration tests
- Middleware stack (in order, `internal/app/app.go`): `RequestLogger`, `Recover`, `CORS` (origin from `CORS_ORIGIN` env, defaults to `"*"`), `Secure` (XSS, nosniff, X-Frame-Options: DENY, Referrer-Policy), custom headers (`Cache-Control: no-store`, `Cross-Origin-Resource-Policy: same-origin`)
- Error envelope uses capital-E `"Error"` key (+ optional `"Index"` for segment errors). Parse/validation errors are 400; 500 is reserved for panics caught by `Recover`

## Known Tech Debt

- **Test data in public package**: `TestFlights` (19 segments) lives in `pkg/api/data.go` — should move to `internal/` or `_test.go`
- **CORS wildcard**: defaults to `"*"` for allowed origins when `CORS_ORIGIN` is unset
- **IATA validation not enforced**: handler accepts any string for source/destination; only the Postman `successSchema` pins the `^[A-Z]{3}$` shape at the E2E layer

## CI Pipeline

- Four workflows: `ci.yml` (single-file layout with tag-gated release jobs), `claude.yml` (interactive + auto-review), `claude-ci-fix.yml` (auto-fix on CI failures with anti-recursion guard), `cleanup-runs.yml` (weekly)
- `ci.yml` jobs: static-check → build/test/integration-test → e2e/dast/docker → (tag-only) goreleaser → ci-pass aggregator
- No separate `release.yml`; tag-gated behavior is `if: startsWith(github.ref, 'refs/tags/')` on relevant steps inside `ci.yml`
- Renovate auto-merges low-risk dependency updates with `chore(all):` prefix
