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

```bash
make deps  # Installs: swag, gosec, benchstat, golangci-lint
```

Manual install if needed:
```bash
go install github.com/swaggo/swag/cmd/swag@latest
go install github.com/securego/gosec/v2/cmd/gosec@latest
go install golang.org/x/perf/cmd/benchstat@latest
curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $(go env GOPATH)/bin
```

## If Tools Not Found

Ensure `$(go env GOPATH)/bin` is in PATH:
```bash
export PATH=$PATH:$(go env GOPATH)/bin
```
