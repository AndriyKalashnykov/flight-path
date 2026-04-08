# Build Specification

## Toolchain

| Tool | Version | Purpose |
|---|---|---|
| Go | 1.26.2 (via gvm) | Language runtime |
| Node.js | LTS (via nvm) | Newman E2E test runner |
| golangci-lint | latest | Linting |
| go-critic | latest | Code review |
| gosec | latest | Security scanning |
| swag | latest | Swagger generation |
| benchstat | latest | Benchmark comparison |
| newman | latest (pnpm) | Postman collection runner |

## Build Flags

```
GOFLAGS=-mod=mod
CGO_ENABLED=0
GOOS=linux
GOARCH=amd64
```

## Dependency Installation (`make deps`)

Installs all missing tools using `command -v` checks:

1. **swag** -- `go install github.com/swaggo/swag/cmd/swag@latest`
2. **gosec** -- `go install github.com/securego/gosec/v2/cmd/gosec@latest`
3. **benchstat** -- `go install golang.org/x/perf/cmd/benchstat@latest`
4. **golangci-lint** -- via install script
5. **Node.js** -- `nvm install --lts && nvm use --lts` (if node not found)
6. **newman** -- `cd test && pnpm install`

## Build Pipeline (`make build`)

```
deps → lint → critic → sec → api-docs → compile
```

1. **deps** -- Install missing tools
2. **lint** -- `golangci-lint run ./...`
3. **critic** -- `gocritic check -enableAll ./...`
4. **sec** -- `gosec ./...`
5. **api-docs** -- `swag init --parseDependency -g main.go`
6. **compile** -- `go build -a -o server main.go` (static binary)

## Run Locally

```bash
make run    # build + go run main.go -env-file .env
```

## Output Artifacts

| Artifact | Location |
|---|---|
| `server` | Project root (Linux amd64 binary) |
| `docs/swagger.json` | Generated OpenAPI 2.0 spec |
| `docs/swagger.yaml` | Generated OpenAPI 2.0 spec (YAML) |
| `docs/docs.go` | Go embed for Swagger |

## Version Management

- Stored in `pkg/api/version.txt` (currently `v0.0.3`)
- Updated during `make release`
