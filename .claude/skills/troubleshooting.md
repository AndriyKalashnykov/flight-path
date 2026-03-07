---
description: Common issues and diagnostic commands
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
go version                # Must match go.mod (1.26.1)
go mod tidy && make build # Clean up and retry
go clean -cache           # Nuclear option
```

- Ensure `GOFLAGS=-mod=mod` is set (Makefile sets this automatically)
- `make build` runs the full chain: `deps lint critic sec api-docs` then compiles

## Tests Fail

```bash
go test -v ./...          # Verbose output
go clean -testcache       # Clear cache
go test -race ./...       # Check for races
```

- `make test` runs `go generate` first, then tests with `TZ="UTC"`
- Benchmarks: `go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s`

## E2E Tests Fail

Server must be running first:
```bash
make run &
sleep 3
make e2e
pkill -f server
```

- Requires Newman: `npm install --location=global newman`
- Tests live in `test/FlightPath.postman_collection.json`
- CI waits 6 seconds for server startup (locally 3s is usually enough)

## Docker Build Fails

```bash
docker buildx ls                    # Check builder exists
docker buildx create --use --name builder --driver docker-container --bootstrap
docker build --no-cache -t flight-path:debug .  # Build without cache
```

- Image: multi-stage Alpine build (`golang:1.26-alpine` -> `alpine:3.23.3`)
- Non-root user: `srvuser:1000`
- `CGO_ENABLED=0`, platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`
- `make build-image` calls `scripts/build-image.sh` which pushes to `andriykalashnykov/flight-path` on Docker Hub

## Tool Not Found

```bash
make deps                           # Install swag, gosec, benchstat, golangci-lint
export PATH=$PATH:$(go env GOPATH)/bin  # Ensure tools are on PATH
```

- `gocritic` is installed by `make critic` (not `make deps`)
- `newman` requires npm: `npm install --location=global newman`

## Diagnostic Commands

```bash
ps aux | grep -E "(server|flight-path)"  # Check processes
lsof -i:8080                              # Check port
curl http://localhost:8080/                # Test health
which swag golangci-lint gosec gocritic newman  # Check tools
go env GOPATH GOROOT                       # Check Go paths
```
