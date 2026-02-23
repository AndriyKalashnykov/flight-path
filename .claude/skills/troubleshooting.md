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

## Swagger Docs Stale

```bash
make api-docs    # Regenerate
pkill -f server  # Restart server
make run
```

Check annotation syntax if generation fails — look at existing handlers for reference.

## Build Fails

```bash
go version                # Must match go.mod (1.26.0)
go mod tidy && make build # Clean up and retry
go clean -cache           # Nuclear option
```

## Tests Fail

```bash
go test -v ./...          # Verbose output
go clean -testcache       # Clear cache
go test -race ./...       # Check for races
```

## E2E Tests Fail

Server must be running first:
```bash
make run &
sleep 3
make e2e
pkill -f server
```

## Docker Build Fails

```bash
docker buildx ls                    # Check builder exists
docker buildx create --use --name builder --driver docker-container --bootstrap
docker build --no-cache -t flight-path:debug .  # Build without cache
```

## Diagnostic Commands

```bash
ps aux | grep -E "(server|flight-path)"  # Check processes
lsof -i:8080                              # Check port
curl http://localhost:8080/                # Test health
which swag golangci-lint gosec newman      # Check tools
```
