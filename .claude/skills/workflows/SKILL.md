---
name: workflows
description: >
  Project-specific development workflows for the flight-path Go project: adding endpoints, benchmarking, releasing, Docker builds, and CI pipelines.
  Use when following a development process, preparing a release, running CI locally, or understanding the build pipeline.
  Do NOT use for environment setup, troubleshooting errors, or debugging specific failures.
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

Quick way:
```bash
make check    # Alias for `make ci` — runs the full local pipeline (see "Local CI" below)
```

Or individual steps:
```bash
make lint           # golangci-lint (60+ linters)
make sec            # gosec security scanner
make vulncheck      # govulncheck dependency check
make secrets        # gitleaks secrets detection
make test           # Unit tests
make api-docs       # Regenerate Swagger docs
make build          # Compile binary (depends on api-docs)
```

## Local CI

```bash
make ci       # full pipeline: deps + static-check + test + integration-test + coverage + coverage-check + build + fuzz + deps-prune-check
make ci-run   # run the GitHub Actions workflow locally via act
```

`make check` is an alias for `make ci`.

## Release

1. Ensure a clean `main` branch with an upstream set
2. `make release` — runs the full `ci` pipeline first, then validates the semver tag (`vN.N.N`), updates `pkg/api/version.txt`, commits, tags, and pushes
3. On the tag push, the tag-gated `goreleaser` and `docker` jobs in `.github/workflows/ci.yml` run (there is **no** separate `release.yml`): GoReleaser builds binaries/archives/checksums + the GitHub Release, and `docker` pushes the cosign-signed multi-arch image to GHCR. They are serialized via `needs:` so a tag produces both artifacts or neither.

`make release` depends on `ci` (the full local pipeline).

## Docker

```bash
make image-build    # Build image locally (single platform, buildx)
make image-run      # Build + run container (binds a free host port, --env-file .env.example)
make image-test     # Build + smoke-test + structure-test
make image-push     # Build + push to GHCR (requires GH_ACCESS_TOKEN)
```

- Image: multi-stage build (`golang:1.26-alpine` -> `alpine:3.23.4`)
- Non-root user: `srvuser:srvgroup` (uid/gid 1000), `CGO_ENABLED=0`
- Platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`
- Registry: GHCR — `make image-push` tags `ghcr.io/<user>/flight-path:<git-tag>`. The release-grade multi-arch build + cosign signing is done by the `docker` job in ci.yml on tag pushes, not by the local target.

## CI Pipeline (GitHub Actions)

Pipeline in `.github/workflows/ci.yml`, runs on push to `main`, tags `v*`, and PRs. A `changes` job (`dorny/paths-filter`) emits a `code` output; heavy jobs gate on `needs.changes.outputs.code == 'true'`, so doc-only changes run only `changes` + `ci-pass`. (Uses a `changes` filter, NOT trigger-level `paths-ignore` — this avoids the Repository-Ruleset deadlock where a skipped workflow never reports the required `ci-pass` check.)

| Job | Needs | What it runs |
|---|---|---|
| `changes` | — | `dorny/paths-filter` — emits the `code` gate output |
| `static-check` | changes | `make static-check` (incl. check-go-alignment, check-docs-go-version, lint, sec, vulncheck, secrets, trivy-fs, mermaid-lint, release-check) |
| `build` | changes, static-check | `make build` + upload binary artifact |
| `test` | changes, static-check | `make coverage` + `make coverage-check` (80%) + `make fuzz` |
| `integration-test` | changes, static-check | `make integration-test` (full HTTP stack via httptest) |
| `e2e` | changes, build, test | Download binary (fallback rebuild), start server, `make e2e-quick` (Newman) |
| `dast` | changes, static-check, test | OWASP ZAP API scan (skipped under `act`) |
| `goreleaser` | changes, static-check, build, test, integration-test, e2e, dast | **tag-only** — GoReleaser binaries/archives/checksums + GitHub Release |
| `docker` | changes, static-check, build, test, integration-test, goreleaser | Build + Trivy image scan + smoke/structure test every push; on tags also push + cosign-sign multi-arch to GHCR |
| `ci-pass` | all of the above | Aggregator (`if: always()`); single required check for branch protection (skipped jobs count as success) |

- Go + Node + the whole quality toolchain are installed by `jdx/mise-action` reading `.mise.toml` (which mirrors `go.mod` and `.nvmrc`) — not `actions/setup-go`/`setup-node`.
- There is **no** `release.yml`; the release phase lives in `ci.yml` as the tag-gated `goreleaser` + `docker` jobs, so `ci-pass` aggregates CI and release into one green check.
- Run the whole workflow locally with `make ci-run` (uses `act`).

## Dependency Updates

- **Automated**: Renovate auto-creates and auto-merges PRs (config: `renovate.json`)
- **Manual**: `make update` (runs `go get -u && go mod tidy`)

## Bumping the Go version

A Go patch bump is **ONE PR** that updates the source-of-truth pins **and**
every live-state doc — never split the doc sweep into a follow-up PR (doing so
is how stale version strings ship).

1. Get the target patch and the new base-image digest, and confirm it:
   ```bash
   docker buildx imagetools inspect golang:1.26-alpine --format '{{.Manifest.Digest}}'
   docker run --rm golang:1.26-alpine@<digest> go version   # MUST show goX.Y.Z
   ```
2. Bump the three pins: `go.mod` (`go X.Y.Z`), `.mise.toml` (`go = "X.Y.Z"`),
   `Dockerfile` (`golang:1.26-alpine@sha256:<digest>` — so the docker job's
   Trivy scan doesn't ship a binary built against the old stdlib).
3. `go mod tidy`; verify the bump cleared what prompted it:
   ```bash
   mise install go@X.Y.Z && mise exec -- govulncheck ./...   # "No vulnerabilities found"
   ```
4. **Sweep every live-state doc in the SAME commit.** Do NOT grep one exact
   version string — grep the broad pattern across the whole tree and inspect
   every hit, then prove zero stale remain:
   ```bash
   git ls-files | xargs grep -nE 'go ?1\.26|gvm' 2>/dev/null   # check each hit
   ```
   Update the patch number AND any version-implied staleness (toolchain manager
   names like `gvm`→`mise`, framework versions). Leave dated history
   (`docs/plan/`, `docs/research/`) unchanged — append, don't rewrite.
5. Prove it before declaring done:
   ```bash
   make check-go-alignment && make check-docs-go-version && make static-check
   ```

`check-docs-go-version` is wired into `static-check`, so a forgotten doc sweep
**reds CI and cannot merge** — it is the mechanical backstop for step 4. See the
project `troubleshooting` skill for the govulncheck-fired-the-bump runbook.

## Quick Test Commands

```bash
make test-case-one    # Single flight: [["SFO", "EWR"]]
make test-case-two    # Two flights: [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three  # Four flights: [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
make open-swagger     # Open Swagger UI in browser
```
