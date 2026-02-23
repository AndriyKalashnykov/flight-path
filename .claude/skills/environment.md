---
description: Development environment setup and tool locations
---

# Development Environment

## Go (via gvm)

```bash
GOROOT=/home/andriy/.gvm/gos/go1.26.0
GOPATH=/home/andriy/.gvm/pkgsets/go1.26.0/global
```

Activated via `~/.zshrc`: `gvm use go1.26.0 --default`

## Node.js (via nvm)

Required for Newman E2E tests: `npm install --location=global newman`

## Tool Installation

`make deps` installs tools only if not already present (idempotent):

| Tool | Installed by | Command |
|---|---|---|
| `swag` | `make deps` | `go install github.com/swaggo/swag/cmd/swag@latest` |
| `gosec` | `make deps` | `go install github.com/securego/gosec/v2/cmd/gosec@latest` |
| `benchstat` | `make deps` | `go install golang.org/x/perf/cmd/benchstat@latest` |
| `golangci-lint` | `make deps` | `curl -sSfL https://golangci-lint.run/install.sh \| sh -s -- -b $(go env GOPATH)/bin` |
| `gocritic` | `make critic` | `go install -v github.com/go-critic/go-critic/cmd/gocritic@latest` |
| `newman` | manual | `npm install --location=global newman` |

Note: `make critic` always reinstalls `gocritic` (not guarded by `command -v` like `make deps` tools).

Most build targets (`lint`, `api-docs`, `bench-save`, `bench-compare`, `build`, `build-image`, `sec`) depend on `deps` and will auto-install missing tools.

## If Tools Not Found

Ensure `$(go env GOPATH)/bin` is in PATH:
```bash
export PATH=$PATH:$(go env GOPATH)/bin
```
