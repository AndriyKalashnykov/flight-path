# Docker Specification

## Multi-Stage Build

### Stage 1: Build (`golang:1.26-alpine`)

- Base: `golang:1.26-alpine` (SHA256-pinned)
- Mount caches for `GOMODCACHE` and `GOCACHE`
- Cross-compile: `CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH`
- Output: `/app/main`

### Stage 2: Runtime (`alpine:3.23.3`)

- Base: `alpine:3.23.3` (SHA256-pinned)
- Non-root user: `srvuser:srvgroup` (UID/GID 1000)
- Binary copied from build stage
- Entrypoint: `["./main"]`

## Build Script (`scripts/build-image.sh`)

| Parameter | Value |
|---|---|
| Registry | `andriykalashnykov` (Docker Hub) |
| Image | `flight-path:latest` |
| Platforms | `linux/amd64`, `linux/arm64`, `linux/arm/v7` |
| Builder | Docker buildx (creates if missing) |

```bash
make build-image    # deps + lint + critic + sec + api-docs + build-image.sh
```

## Running

```bash
docker run -p 8080:8080 andriykalashnykov/flight-path:latest
```

## Notes

- `.env` is NOT in runtime image (only binary is copied)
- `SERVER_PORT` defaults to `8080` if unset
- Container runs as non-root (UID 1000)
- Commented alternatives in Dockerfile: Red Hat UBI 9, Google Distroless
