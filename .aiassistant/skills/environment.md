---
description: Development environment setup and tool locations
---

# Development Environment

## Go Compiler (via gvm)

### Active Version
- **Go Version**: Check `go.mod` file for required version (currently 1.26.0)
- **Managed by**: gvm (Go Version Manager)
- **Important**: Always reference `go.mod` for the active Go version requirement

### Paths
```bash
GOROOT=/home/andriy/.gvm/gos/go1.26.0
GOPATH=/home/andriy/.gvm/pkgsets/go1.26.0/global
GVM_ROOT=/home/andriy/.gvm
```

### Binaries
- **go**: `/home/andriy/.gvm/gos/go1.26.0/bin/go`
- **gofmt**: `/home/andriy/.gvm/gos/go1.26.0/bin/gofmt`

### Environment Activation
The Go environment is automatically loaded via `~/.zshrc`:
```bash
[[ -s "/home/andriy/.gvm/scripts/gvm" ]] && source "/home/andriy/.gvm/scripts/gvm"
gvm use go1.26.0 --default
```

### Available Go Versions
- go1.26.0 (active/default)

## Node.js (via nvm)

### Purpose
- Required for Postman/Newman E2E tests
- Frontend development tools (if needed)

### Installation
```bash
nvm install --lts
nvm use --lts
npm install yarn --global
npm install npm --global
npm install -g pnpm
pnpm add -g pnpm
```

### Newman CLI
```bash
npm install --location=global newman
```

## Development Tools

### Required Tools
Install all required tools with:
```bash
make deps
```

This installs:
- **swag**: Swagger documentation generator (`github.com/swaggo/swag/cmd/swag`)
- **gosec**: Security checker (`github.com/securego/gosec/v2/cmd/gosec`)
- **benchstat**: Benchmark comparison tool (`golang.org/x/perf/cmd/benchstat`)
- **golangci-lint**: Comprehensive linter
- **gocritic**: Additional code critic

### Manual Installation
If needed, install individually:
```bash
# Swagger
go install github.com/swaggo/swag/cmd/swag@latest

# Security scanner
go install github.com/securego/gosec/v2/cmd/gosec@latest

# Benchmark comparison
go install golang.org/x/perf/cmd/benchstat@latest

# Linter
curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $(go env GOPATH)/bin

# Code critic
go install -v github.com/go-critic/go-critic/cmd/gocritic@latest
```

## Usage Notes

When running Go commands in a new shell session, the environment should already be active. If not, source gvm:
```bash
source ~/.gvm/scripts/gvm
gvm use go1.26.0
```

For this project, always check and use the Go version specified in `go.mod`.

## Build Flags
This project uses:
```bash
GOFLAGS=-mod=mod
```
Set in Makefile for all Go operations.

## Common Commands

### Development Workflow
```bash
make deps          # Install required tools (first time setup)
make api-docs      # Generate Swagger documentation
make lint          # Run linter checks
make critic        # Run code critic
make sec           # Run security checks
make test          # Run tests
make build         # Build server binary
make run           # Build and run server (port 8080)
```

### Testing
```bash
make test                # Run unit tests
make bench               # Run benchmark tests
make bench-save          # Save benchmark results
make bench-compare       # Compare two benchmark runs
make e2e                 # Run Postman/Newman E2E tests
make test-case-one       # Test simple flight path
make test-case-two       # Test two-segment path
make test-case-three     # Test complex multi-segment path
```

### Development
```bash
make run                 # Run server locally (http://localhost:8080)
make open-swagger        # Open Swagger UI in browser
```

### Maintenance
```bash
make update              # Update Go dependencies
make release             # Create and push new version tag
```

## Project Structure

```
flight-path/
├── main.go              # Entry point, server setup, Swagger config
├── go.mod               # Go module dependencies
├── Makefile             # Build and development commands
├── .env                 # Environment variables
├── Dockerfile           # Docker image build
├── internal/            # Private application code
│   ├── handlers/        # Business logic and request handlers
│   └── routes/          # Route registration
├── pkg/                 # Public packages
│   └── api/             # API types and data structures
├── docs/                # Generated Swagger documentation
├── test/                # E2E test collections
├── benchmarks/          # Saved benchmark results
└── scripts/             # Build and utility scripts
```

## Server Configuration

### Default Settings
- **Port**: 8080
- **Swagger UI**: http://localhost:8080/swagger/index.html
- **API Endpoint**: http://localhost:8080/calculate

### Environment Variables
Configure via `.env` file:
```
# Add project-specific environment variables here
```

Load with:
```bash
go run main.go -env-file .env
```

## Troubleshooting

### Port Already in Use
If port 8080 is busy:
```bash
lsof -ti:8080 | xargs kill -9
# Or
pkill -f "flight-path/server"
```

### Tool Not Found
If commands fail with "command not found":
```bash
# Reinstall dependencies
make deps

# Check if Go bin is in PATH
echo $PATH | grep GOPATH

# Manually add to PATH if needed
export PATH=$PATH:$(go env GOPATH)/bin
```

### Swagger Generation Fails
```bash
# Ensure swag is installed
go install github.com/swaggo/swag/cmd/swag@latest

# Regenerate
make api-docs
```

### Tests Fail
```bash
# Ensure all tools are installed
make deps

# Clean and rebuild
go clean -cache
make build
make test
```

## CI/CD Integration

### GitHub Actions
The CI workflow requires:
- Go 1.26.0+
- Node.js (for Newman)
- All tools from `make deps`

Steps run automatically:
1. Install dependencies
2. Install Newman
3. Run tests
4. Build binary
5. Start server
6. Run E2E tests

### Local CI Simulation
Run the same checks locally:
```bash
make deps
make lint
make critic
make sec
make test
make build
make run &
sleep 5
make e2e
pkill -f server
```
