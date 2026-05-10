# Build Specification

## Toolchain

Go and Node are provisioned by [mise](https://mise.jdx.dev/) from `.mise.toml` (plus `go.mod` for Go). Every quality/security tool below is also pinned in `.mise.toml` as a single source of truth, consumed by both `make deps` locally and `jdx/mise-action` in CI.

| Tool | Source of truth | Purpose |
|---|---|---|
| Go | `go.mod` + `.mise.toml` | Language runtime (currently 1.26.3) |
| Node.js | `.nvmrc` + `.mise.toml` | Newman E2E runner (currently major 24) |
| golangci-lint | `.mise.toml` | Meta-linter (configured via `.golangci.yml`) |
| gosec | `.mise.toml` (aqua:securego/gosec) | Security scanner |
| govulncheck | `.mise.toml` (go: backend) | Dependency vulnerability check |
| gitleaks | `.mise.toml` | Secret detection |
| actionlint | `.mise.toml` | GitHub Actions linter |
| shellcheck | `.mise.toml` | Shell script linter (invoked by actionlint) |
| hadolint | `.mise.toml` | Dockerfile linter |
| trivy | `.mise.toml` | Image + filesystem vulnerability scanner |
| act | `.mise.toml` | Local GitHub Actions runner |
| goreleaser | `.mise.toml` | Release binary builder + `.goreleaser.yml` validator |
| swag | Go install pinned via `SWAG_VERSION` in `Makefile` | Swagger code generator (no stable mise backend) |
| benchstat | Go install pinned via `BENCHSTAT_VERSION` in `Makefile` | Benchmark comparison |
| newman | `pnpm install` in `test/` (pinned in `test/package.json`) | Postman collection runner |
| mermaid-cli | Docker image pinned via `MERMAID_CLI_VERSION` in `Makefile` | Mermaid diagram validator |

## Build Flags

```
GOFLAGS=-mod=mod
CGO_ENABLED=0
GOOS=linux
GOARCH=amd64
```

The Docker image build additionally honors `TARGETOS` / `TARGETARCH` for cross-compilation (see `DOCKER.md`).

## Dependency Installation (`make deps`)

1. Install `mise` if not on `PATH`
2. `mise install --yes` — provisions Go, Node, and every tool pinned in `.mise.toml`
3. `go install` for `swag` and `benchstat` (no stable mise backend)
4. Enable `corepack` and `pnpm install` in `test/` for Newman

`make deps-check` reports the Go version, mise status, and which tools resolve on `PATH`.

## Build Pipeline (`make build`)

```
api-docs → go build
```

1. **api-docs** — `swag init --parseDependency -g main.go` regenerates `docs/swagger.{json,yaml,go}` from handler annotations
2. **go build** — `go build -a -o server main.go` (static binary via `CGO_ENABLED=0`)

Upstream quality/security gates (lint, sec, vulncheck, secrets, trivy-fs, mermaid-lint, release-check) live in `make static-check` and are not prerequisites of `make build` — they run in their own CI job and in `make ci`.

## Run Locally

```bash
make run    # go build + ./server
```

## Output Artifacts

| Artifact | Location |
|---|---|
| `server` | Project root (statically linked binary; `GOOS`/`GOARCH` honored) |
| `docs/swagger.json` | Generated OpenAPI 2.0 spec (swag v2 still emits swagger 2.0) |
| `docs/swagger.yaml` | Generated OpenAPI 2.0 spec (YAML) |
| `docs/docs.go` | Go embed used by `swaggo/echo-swagger/v2` |

## Version Management

- Stored in `pkg/api/version.txt`
- Bumped during `make release`, which runs the full CI pipeline, tags, and pushes to trigger the tag-gated release jobs in `.github/workflows/ci.yml`
