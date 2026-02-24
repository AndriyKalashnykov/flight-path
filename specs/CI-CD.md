# CI/CD Specification

## CI Pipeline (`.github/workflows/ci.yml`)

**Triggers**: All pushes and pull requests

```
static-check → builds → tests → integration
```

### static-check (10min timeout)
- `make deps lint critic sec`

### builds (10min timeout, depends: static-check)
- Setup Go from `go.mod`
- `make build`

### tests (depends: builds)
- Matrix: `[unit]`
- `make test`

### integration (20min timeout, depends: builds + tests)
- Setup Go + Node.js (LTS)
- Install Newman
- `make build`
- Start server in background (`go run main.go -env-file .env &`)
- Wait 6 seconds
- `make e2e` (Newman/Postman E2E tests)

**Permissions**: `contents: write`, `packages: write`

## Release Pipeline (`.github/workflows/release.yml`)

**Triggers**: Tag push (`*`)

1. Checkout + Setup Go 1.26.0
2. Docker login to GHCR (`ghcr.io`)
3. GoReleaser (`goreleaser/goreleaser-action@v7`) with `.goreleaser.yml`

**Secrets**: `GH_ACCESS_TOKEN` (GHCR), `GITHUB_TOKEN` (GoReleaser)

## Release Process (`make release`)

1. `make api-docs build`
2. Prompt for new tag
3. Write to `pkg/api/version.txt`
4. `git add -A && git commit -a -s -m "Cut {tag} release"`
5. `git tag {tag} && git push origin {tag} && git push`
6. GitHub Actions release workflow triggers

## Dependency Automation

Renovate (`renovate.json`) for automated dependency update PRs.
