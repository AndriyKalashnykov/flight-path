---
name: troubleshooting
description: >
  Diagnose and fix common issues in the flight-path project: build failures, test failures, port conflicts, Docker problems, and tool errors.
  Use when something fails, an error occurs, the server won't start, or a command produces unexpected output.
  Do NOT use for environment setup, workflow guidance, or adding new features.
---

# Troubleshooting

## Port 8080 in Use

```bash
lsof -ti:8080 | xargs kill -9
# or
pkill -f "flight-path/server"
```

## API Returns 404

- Health check is `GET /` (not `/health`)
- Calculate is `POST /calculate` (not GET)
- Check Swagger: http://localhost:8080/swagger/index.html

## API Returns 500

- Check server terminal for error logs
- Test with minimal input: `curl -X POST http://localhost:8080/calculate -H 'Content-Type: application/json' -d '[["SFO", "EWR"]]'`
- Verify input format: `[][]string` — each segment must be exactly 2 airport codes

## Swagger Docs Stale

```bash
make api-docs    # Regenerate from annotations
pkill -f server  # Restart server
make run
```

- If generation fails, check Swagger annotation syntax against existing handlers in `internal/handlers/`
- Hard-refresh browser (Ctrl+Shift+R) to clear cached Swagger UI

## Build Fails

```bash
go version                # Must match the `go` directive in go.mod
go mod tidy && make build # Clean up and retry
go clean -cache           # Nuclear option
```

- `make build` depends on `api-docs` (which depends on `deps`), then compiles
- Ensure `GOFLAGS=-mod=mod` is set (Makefile sets this automatically)
- Use `make check` for the full pre-commit chain: `lint sec vulncheck secrets test api-docs build`

## `static-check` / `govulncheck` Fails on an Unrelated PR (Go stdlib CVE)

**Symptom:** An open PR that touches no Go code — e.g. a Renovate GitHub Actions
SHA bump — fails the `static-check` job at the `govulncheck` step. Multiple
in-flight PRs fail identically.

**Root cause:** `govulncheck` flags a Go **standard-library** vulnerability
present in the pinned Go patch on `main`. The failure lives in `main`'s
toolchain, not the PR diff, so it surfaces on *every* PR's `static-check`.
This is the "N in-flight PRs failing identically → diagnose `main`, not the
PRs" pattern. It recurs each time a Go patch ships stdlib security fixes.

**Diagnose** — read the actual failing step, don't guess:
```bash
gh run view <run-id> --log-failed | grep -A4 'Vulnerability #'
# Look for: "Standard library", "Found in: <pkg>@goX.Y.Z", "Fixed in: <pkg>@goX.Y.W"
```

**Fix (real fix — bump Go; NEVER waive a reachable stdlib CVE).** Bump the Go
patch across all three pins in ONE change (mirrors Renovate's "Go toolchain"
group so the managers stay consistent):

| File | Line |
|------|------|
| `go.mod` | `go X.Y.W` |
| `.mise.toml` | `go = "X.Y.W"` |
| `Dockerfile` | `golang:1.26-alpine@sha256:<digest>` — refresh so the `docker` job's Trivy scan doesn't ship a binary built against the old stdlib |

Get the new digest and confirm it is the fixed patch *before* editing:
```bash
docker buildx imagetools inspect golang:1.26-alpine --format '{{.Manifest.Digest}}'
docker run --rm golang:1.26-alpine@<digest> go version   # MUST show the fixed patch goX.Y.W
```

Verify locally before pushing (this is the proof, not a hope):
```bash
mise install go@X.Y.W
mise exec -- govulncheck ./...   # must report "No vulnerabilities found"
make static-check                # the full gate that was failing
make check-go-alignment          # go.mod and .mise.toml must agree
```

**The bump is not done at the pins — sweep the docs in the SAME PR.** Prose
docs (`README.md`, `CLAUDE.md`, `specs/`, `docs/ARCHITECTURE.md`, the
`.claude/agents/*.md` and `.claude/skills/*.md` files) are not touched by
Renovate and go stale on merge. Do NOT grep one exact version string — grep the
broad pattern across the whole tree and prove zero stale remain:
```bash
git ls-files | xargs grep -nE 'go ?1\.26|gvm' 2>/dev/null   # inspect every hit
make check-docs-go-version                                   # the drift gate; must pass
```
`check-docs-go-version` runs inside `static-check` and reds CI if any live-state
doc still shows an old Go patch — never declare the bump done until it is green.
Full procedure: the "Bumping the Go version" checklist in the `workflows` skill.

Then PR the fix to `main` (do NOT push onto the Renovate branch — it can
auto-merge from under you). Renovate auto-rebases the in-flight PRs onto the
fix and they go green.

**Why Renovate didn't bump it first:** Go patches ship ~monthly and
`govulncheck` flips red the instant a CVE is disclosed — faster than any
Renovate schedule + CI + automerge cycle, so a manual bump-on-red is the
correct fast path. Additionally, if past Go bumps were applied **manually**
(as stdlib-CVE fires force), Renovate's gomod extraction diverges and the
"Go toolchain" group stops firing. Tell: the Renovate Dependency Dashboard
(issue #8) freezes at an old `go` version and lists deps the repo no longer
has. To re-engage it, tick the rebase/refresh checkbox on the Dashboard to
force a fresh extraction.

## Tests Fail

```bash
go test -v ./...          # Verbose output
go clean -testcache       # Clear cache
go test -race ./...       # Check for races
```

- `make test` runs tests with `TZ="UTC"` and `GOFLAGS=-mod=mod`
- Benchmarks: `go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s`

## E2E Tests Fail

Server must be running first:
```bash
make run &
sleep 3
make e2e
pkill -f server
```

- `make e2e` depends on `deps` (installs Newman if missing)
- Tests live in `test/FlightPath.postman_collection.json`
- CI polls with curl for up to 30 seconds for server startup

## Docker Build Fails

```bash
docker buildx ls                    # Check builder exists
docker buildx create --use --name builder --driver docker-container --bootstrap
make image-build                    # Build locally (single platform, uses buildx)
docker build --no-cache -t flight-path:debug .  # Build without cache
```

- Image: multi-stage Alpine build (`golang:1.26-alpine` -> `alpine:3.23.3`)
- Non-root user: `srvuser:1000`
- `CGO_ENABLED=0`, platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`
- `make build-image` runs checks first (`deps api-docs lint sec vulncheck secrets`) then pushes to Docker Hub

## Docker Container Crashes at Runtime

Known issue: `.env` file is not copied into the Docker runtime stage, and `godotenv.Load()` calls `log.Fatalf` on error.

Workaround: pass `SERVER_PORT` as environment variable:
```bash
docker run -d -p 8080:8080 -e SERVER_PORT=8080 flight-path:local
```

Or use `make image-run` / `make image-test` which handle this automatically.

## Tool Not Found

```bash
make deps                           # Install all tools
export PATH=$PATH:$(go env GOPATH)/bin  # Ensure tools are on PATH
```

- `newman` requires Node.js — `make deps` installs both via nvm/npm

## Diagnostic Commands

```bash
ps aux | grep -E "(server|flight-path)"  # Check processes
lsof -i:8080                              # Check port
curl http://localhost:8080/                # Test health
which swag golangci-lint gosec govulncheck gitleaks actionlint newman  # Check tools
go env GOPATH GOROOT                       # Check Go paths
make check                                # Run full pre-commit checklist
```
