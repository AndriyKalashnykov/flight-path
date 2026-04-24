# Docker Specification

## Multi-Stage Build

### Stage 1: Build (`golang:1.26-alpine`)

- Base: `golang:1.26-alpine` (SHA256-pinned, Renovate-tracked via inline comment in `Dockerfile`)
- Mount caches for `GOMODCACHE` and `GOCACHE`
- Cross-compile: `CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH`
- Output: `/app/main`

### Stage 2: Runtime (`alpine:3.23.3`)

- Base: `alpine:3.23.3` (SHA256-pinned, Renovate-tracked)
- Non-root user: `srvuser:srvgroup` (UID/GID 1000)
- `HEALTHCHECK` hits `localhost:${SERVER_PORT:-8080}` (no `EXPOSE` directive — port is honored only at runtime via env)
- Binary copied from build stage
- Entrypoint: `["./main"]`

## Build & Publish

Image builds use `docker buildx` directly (invoked by Makefile targets and the `docker` CI job — no separate build script).

| Parameter | Value |
|---|---|
| Registry | `ghcr.io/andriykalashnykov` (GitHub Container Registry) |
| Image | `ghcr.io/andriykalashnykov/flight-path:<tag>` |
| Platforms | `linux/amd64`, `linux/arm64` |
| Multi-arch pattern | Pattern A: `provenance: false` + `sbom: false` — yields a clean image index so the GHCR "OS / Arch" tab renders without `unknown/unknown` rows |
| Signing | Cosign keyless OIDC (`sigstore/cosign-installer` + `cosign sign --yes <digest>`), tag-gated |

### Makefile targets

| Target | Purpose |
|---|---|
| `make image-build` | Single-arch local build (loaded into the host Docker daemon) |
| `make image-run` / `make image-stop` | Start/stop a detached container for local probing |
| `make image-push` | Push to GHCR (requires `GH_ACCESS_TOKEN`; `GHCR_USER` defaults to `git config user.name`) |
| `make image-smoke-test` | Start container, assert `GET /` and `POST /calculate` return 200, tear down |
| `make image-test` | `image-build` + `image-smoke-test` |
| `make image-scan` | Build image and run Trivy |
| `make trivy-fs` | Filesystem vulnerability scan (uses `.trivyignore` if present) |
| `make trivy-image` | Image vulnerability scan |

### CI gates (`docker` job in `.github/workflows/ci.yml`)

The `docker` job runs on every push. Gates 1–3 run unconditionally; Gate 4 builds multi-arch on every push and only pushes on tag. Gate 5 is tag-only.

| # | Gate | What it catches |
|---|---|---|
| 1 | Single-arch build + `load: true` | Build regressions on runner architecture |
| 2 | Trivy image scan (CRITICAL/HIGH blocking) | CVEs, secrets, misconfigs in base + build layers |
| 3 | `make image-smoke-test` | Image boots, endpoints respond |
| 4 | Multi-arch buildx (`linux/amd64`, `linux/arm64`); push on tags only | Cross-compile regressions even on non-tag pushes |
| 5 | Cosign keyless OIDC signing (tag only) | Sigstore signature on the manifest digest |

## Running

```bash
docker run -p 8080:8080 ghcr.io/andriykalashnykov/flight-path:<tag>
```

## Inspection & Verification

```bash
# Inspect multi-arch manifest (expect amd64 + arm64, no unknown/unknown rows)
docker buildx imagetools inspect ghcr.io/andriykalashnykov/flight-path:<tag>

# Verify cosign signature
cosign verify ghcr.io/andriykalashnykov/flight-path:<tag> \
  --certificate-identity-regexp 'https://github\.com/AndriyKalashnykov/flight-path/\.github/workflows/ci\.yml@refs/tags/v.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Notes

- `.env` is NOT copied into the runtime image — only the binary
- `SERVER_PORT` defaults to `8080` when unset
- Container runs as non-root (UID 1000)
- Commented alternatives in `Dockerfile`: Red Hat UBI 9, Google Distroless
