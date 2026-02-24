# Build Specification

## Toolchain

| Tool | Version | Purpose |
|---|---|---|
| Go | 1.26.0 (via gvm) | Language runtime |
| Node.js | LTS (via nvm) | Newman E2E test runner |
| golangci-lint | latest | Linting |
| go-critic | latest | Code review |
| gosec | latest | Security scanning |
| swag | latest | Swagger generation |
| benchstat | latest | Benchmark comparison |
| newman | latest (npm) | Postman collection runner |

## Build Flags

```
GOFLAGS=-mod=mod
CGO_ENABLED=0
GOOS=linux
GOARCH=amd64
```

## Build Pipeline (`make build`)

```
deps → lint → critic → sec → api-docs → compile
```

1. **deps** -- Install missing tools (skips installed via `command -v`)
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
