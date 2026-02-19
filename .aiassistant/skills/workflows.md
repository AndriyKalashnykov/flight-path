---
description: Common development workflows and procedures
---

# Development Workflows

## Initial Setup Workflow

### First Time Repository Setup
```bash
# 1. Clone repository
git clone https://github.com/AndriyKalashnykov/flight-path.git
cd flight-path

# 2. Verify Go version
go version  # Should be 1.26.0 or compatible
cat go.mod | grep "^go"  # Check required version

# 3. Install development tools
make deps

# 4. Verify tool installation
which swag
which golangci-lint
which gosec
which newman

# 5. Generate Swagger documentation
make api-docs

# 6. Run tests to verify setup
make test

# 7. Build the project
make build

# 8. Run the server
make run
# Server should start on http://localhost:8080

# 9. Test in another terminal
curl http://localhost:8080/
make test-case-one

# 10. Open Swagger UI
make open-swagger
# Or manually: http://localhost:8080/swagger/index.html
```

---

## Daily Development Workflow

### Standard Development Cycle
```bash
# 1. Start work - ensure clean state
git status
git pull origin main

# 2. Create feature branch (optional)
git checkout -b feature/my-feature

# 3. Make code changes
# Edit files...

# 4. Run checks frequently
make lint          # Check code style
make test          # Run tests
make api-docs      # Update Swagger if API changed

# 5. Test manually
make run           # Start server
# In another terminal:
make test-case-one
curl -X POST http://localhost:8080/calculate -H 'Content-Type: application/json' -d '[["SFO","EWR"]]'

# 6. Before committing
make lint          # ✓ Pass
make critic        # ✓ Pass
make sec           # ✓ Pass
make test          # ✓ Pass
make build         # ✓ Pass

# 7. Commit changes
git add .
git commit -m "feat: add new feature"

# 8. Push changes
git push origin feature/my-feature
```

---

## Adding a New API Endpoint

### Step-by-Step Process

**1. Define the handler with Swagger annotations:**
```go
// internal/handlers/my_handler.go

// MyNewEndpoint godoc
// @Summary Brief description
// @Description Detailed description
// @Tags MyTag
// @ID my-endpoint
// @Accept json
// @Produce json
// @Param input body MyInputType true "Input description"
// @Success 200 {object} MyOutputType
// @Failure 400 {object} map[string]interface{}
// @Failure 500 {object} map[string]interface{}
// @Router /my-endpoint [post]
func MyNewEndpoint(c echo.Context) error {
    var input MyInputType
    if err := c.Bind(&input); err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid input"})
    }

    // Validate input
    if err := validateInput(input); err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
    }

    // Process
    result, err := processData(input)
    if err != nil {
        return c.JSON(http.StatusInternalServerError, map[string]string{"error": "processing failed"})
    }

    return c.JSON(http.StatusOK, result)
}
```

**2. Register the route:**
```go
// internal/routes/my_route.go

func RegisterMyRoutes(e *echo.Echo) {
    e.POST("/my-endpoint", handlers.MyNewEndpoint)
}
```

**3. Register in main.go:**
```go
// main.go

func main() {
    e := echo.New()

    // ... existing setup ...

    routes.RegisterMyRoutes(e)  // Add this line

    e.Logger.Fatal(e.Start(":8080"))
}
```

**4. Generate Swagger docs:**
```bash
make api-docs
```

**5. Write tests:**
```go
// internal/handlers/my_handler_test.go

func TestMyNewEndpoint(t *testing.T) {
    e := echo.New()
    req := httptest.NewRequest(http.MethodPost, "/my-endpoint", strings.NewReader(`{"key":"value"}`))
    req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
    rec := httptest.NewRecorder()
    c := e.NewContext(req, rec)

    if err := MyNewEndpoint(c); err != nil {
        t.Fatal(err)
    }

    if rec.Code != http.StatusOK {
        t.Errorf("expected 200, got %d", rec.Code)
    }
}
```

**6. Add Newman/Postman test:**
Edit `test/FlightPath.postman_collection.json` to add test case.

**7. Test and verify:**
```bash
make test          # Unit tests pass
make build         # Build succeeds
make run &         # Start server
make e2e           # E2E tests pass
pkill -f server    # Stop server
```

---

## Performance Optimization Workflow

### Benchmarking and Optimization

**1. Identify performance issue:**
```bash
# Run current benchmarks
make bench

# Look for slow operations
# BenchmarkCalculateFlightPath-8   100000   12000 ns/op   (too slow!)
```

**2. Save baseline:**
```bash
make bench-save
# Saves to: benchmarks/bench_YYYYMMDD_HHMMSS.txt
```

**3. Profile the code (if needed):**
```bash
# CPU profile
go test -cpuprofile=cpu.prof -bench=.
go tool pprof cpu.prof

# Memory profile
go test -memprofile=mem.prof -bench=.
go tool pprof mem.prof
```

**4. Implement optimization:**
- Change algorithm
- Use better data structures
- Reduce allocations
- Cache results

**5. Benchmark again:**
```bash
make bench-save
```

**6. Compare results:**
```bash
make bench-compare
# Or specify files:
# make bench-compare OLD=benchmarks/bench_20260217_100000.txt NEW=benchmarks/bench_20260217_110000.txt
```

**7. Verify correctness:**
```bash
make test  # Ensure tests still pass
```

**8. Document improvement:**
```
git commit -m "perf: optimize flight path calculation

Improved algorithm from O(n²) to O(n) by using map lookups
instead of nested loops.

Benchmark comparison:
BenchmarkCalculateFlightPath-8
  Before: 12000 ns/op
  After:   2000 ns/op
  Improvement: 83% faster
"
```

---

## Debugging Workflow

### When Something Goes Wrong

**1. Identify the problem:**
```bash
# Server not starting?
make run
# Read error messages

# Tests failing?
make test
# Read test output

# API returning errors?
curl -v -X POST http://localhost:8080/calculate \
  -H 'Content-Type: application/json' \
  -d '[["SFO","EWR"]]'
```

**2. Add debug logging:**
```go
import "log"

func MyHandler(c echo.Context) error {
    log.Printf("DEBUG: received request: %+v", c.Request())

    var input [][]string
    if err := c.Bind(&input); err != nil {
        log.Printf("DEBUG: bind error: %v", err)
        return c.JSON(400, map[string]string{"error": "invalid input"})
    }

    log.Printf("DEBUG: input data: %+v", input)
    // ... rest of handler
}
```

**3. Run with verbose output:**
```bash
# Verbose tests
go test -v ./...

# Verbose server (if you add logging)
make run
```

**4. Use test cases:**
```bash
# Test specific scenarios
make test-case-one
make test-case-two
make test-case-three

# Or custom test
curl -X POST http://localhost:8080/calculate \
  -H 'Content-Type: application/json' \
  -d '[["A","B"],["C","D"]]'
```

**5. Check generated files:**
```bash
# Ensure Swagger docs are up to date
make api-docs
cat docs/swagger.json

# Verify build artifacts
make build
ls -lh server
```

**6. Fix and verify:**
```bash
# After fixing
make test
make build
make run
make test-case-one
```

---

## Code Review Workflow

### Before Creating Pull Request

**1. Self-review checklist:**
```bash
# Code quality
make lint          # ✓ No linting errors
make critic        # ✓ No critical issues
make sec           # ✓ No security issues

# Functionality
make test          # ✓ All tests pass
make build         # ✓ Builds successfully

# Documentation
make api-docs      # ✓ Swagger docs updated
# Review docs/swagger.json

# Manual testing
make run &
sleep 2
make test-case-one
make test-case-two
make test-case-three
make e2e
pkill -f server
```

**2. Clean up code:**
```bash
# Format code
go fmt ./...

# Clean up imports
goimports -w .

# Remove debug statements
# Remove commented code
# Verify commit messages
```

**3. Update documentation:**
```
# Update README.md if needed
# Update .aiassistant/memory.md for important changes
# Ensure code comments are clear
# Update Swagger comments if API changed
```

**4. Create PR:**
```bash
git push origin feature/my-feature
# Create PR on GitHub
# Fill in PR description with:
# - What changed
# - Why it changed
# - How to test
# - Benchmark results (if applicable)
```

---

## Release Workflow

### Creating a New Release

**1. Ensure clean state:**
```bash
git checkout main
git pull origin main
git status  # Should be clean
```

**2. Run full test suite:**
```bash
make deps
make lint
make critic
make sec
make test
make build
```

**3. Update version:**
```bash
# Version is in pkg/api/version.txt
echo "v1.2.3" > pkg/api/version.txt
```

**4. Create release:**
```bash
make release
# This will:
# - Prompt for new version tag
# - Update version.txt
# - Commit changes
# - Create git tag
# - Push tag and commits
```

**5. Verify release:**
```bash
git tag -l
git log --oneline -5
```

---

## Rollback Workflow

### Reverting Changes

**1. Identify problematic commit:**
```bash
git log --oneline
```

**2. Revert specific commit:**
```bash
git revert <commit-hash>
git push origin main
```

**3. Revert to previous version:**
```bash
# Create branch from previous tag
git checkout -b hotfix/rollback v1.2.2
git push origin hotfix/rollback
```

**4. Emergency rollback:**
```bash
git reset --hard <good-commit>
git push --force origin main  # Use with caution!
```

---

## Continuous Integration Workflow

### CI Pipeline Expectations

When you push code, GitHub Actions will:

1. ✓ Checkout code
2. ✓ Setup Node.js (for Newman)
3. ✓ Setup Go 1.26.0
4. ✓ Install dependencies (`make deps`)
5. ✓ Install Newman
6. ✓ Run tests (`make test`)
7. ✓ Build binary (`make build`)
8. ✓ Start server
9. ✓ Wait for server ready
10. ✓ Run E2E tests (`make e2e`)

### If CI Fails

**1. Check CI logs on GitHub**

**2. Reproduce locally:**
```bash
# Run the same steps as CI
make deps
make test
make build
./server &
sleep 5
make e2e
pkill -f server
```

**3. Fix and push:**
```bash
# Fix the issue
git add .
git commit -m "fix: resolve CI failure"
git push
```

---

## Dependency Update Workflow

### Updating Dependencies

**1. Check for updates:**
```bash
go list -u -m all
```

**2. Update dependencies:**
```bash
make update
# This runs: go get -u && go mod tidy
```

**3. Test thoroughly:**
```bash
make test
make build
make run &
make e2e
pkill -f server
```

**4. Commit:**
```bash
git add go.mod go.sum
git commit -m "chore: update dependencies"
```

### Renovate Bot
- Renovate automatically creates PRs for dependency updates
- Review and test before merging
- Check for breaking changes in changelogs
- Renovate configuration in `renovate.json`:
  - Auto-merges all updates when checks pass
  - Pins Docker digests for security
  - Runs `go mod tidy` after updates
  - Creates dependency dashboard
  - Labels PRs with `dependencies`

---

## Docker Workflow

### Building Docker Images

**1. Build multi-platform image:**
```bash
make build-image
# This will:
# - Create or use existing buildx builder
# - Build for linux/amd64, linux/arm64, linux/arm/v7
# - Push to andriykalashnykov/flight-path:latest
```

**2. Build locally for testing:**
```bash
docker build -t flight-path:local .
```

**3. Run container locally:**
```bash
# Run container
docker run -p 8080:8080 flight-path:local

# Run in background
docker run -d -p 8080:8080 --name flight-path flight-path:local

# View logs
docker logs -f flight-path

# Stop container
docker stop flight-path
docker rm flight-path
```

**4. Test containerized application:**
```bash
# Ensure container is running
docker ps | grep flight-path

# Test endpoint
curl http://localhost:8080/
make test-case-one

# Run Newman tests against container
make e2e
```

**5. Multi-stage build verification:**
```bash
# Check image size (should be minimal due to alpine/distroless)
docker images | grep flight-path

# Inspect image layers
docker history flight-path:local

# Check running processes in container
docker exec flight-path ps aux
```

**6. Security scanning:**
```bash
# Scan for vulnerabilities (requires Docker Scout or similar)
docker scout cves flight-path:local

# Or use trivy
trivy image flight-path:local
```

### Docker Best Practices in This Project

The Dockerfile uses several best practices:
- Multi-stage build (build stage + runtime stage)
- Build cache mounting for Go modules and build cache
- Multi-platform support (amd64, arm64, arm/v7)
- Minimal runtime image (Alpine 3.23.3)
- Non-root user (srvuser:srvgroup with UID/GID 1000)
- Pinned base images with SHA256 digests
- Static binary (CGO_ENABLED=0)

---

## Git Workflow

### Branch Management

**1. Working with feature branches:**
```bash
# Create and switch to new branch
git checkout -b feature/add-caching

# Make changes and commit
git add .
git commit -m "feat: add response caching"

# Keep branch updated with main
git fetch origin
git rebase origin/main

# Push branch
git push origin feature/add-caching
```

**2. Cleaning up branches:**
```bash
# List local branches
git branch

# Delete local branch
git branch -d feature/old-feature

# Delete remote branch
git push origin --delete feature/old-feature

# Prune deleted remote branches
git fetch --prune
```

**3. Checking out PRs locally:**
```bash
# Fetch PR #123 to local branch pr-123
git fetch origin pull/123/head:pr-123
git checkout pr-123

# Test the PR
make test
make build
make run
```

### Commit Message Conventions

Follow conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

**Examples:**
```bash
git commit -m "feat(api): add caching to calculate endpoint"
git commit -m "fix(handlers): handle empty flight segments"
git commit -m "perf(calculate): optimize path sorting algorithm"
git commit -m "docs(readme): update installation instructions"
git commit -m "chore(deps): update echo to v5.0.4"
```

### Git Tips

**1. Amend last commit:**
```bash
# Change commit message
git commit --amend -m "New message"

# Add forgotten files to last commit
git add forgotten_file.go
git commit --amend --no-edit
```

**2. Interactive rebase:**
```bash
# Rebase last 3 commits
git rebase -i HEAD~3

# Options: pick, reword, edit, squash, fixup, drop
```

**3. Stash changes:**
```bash
# Save work in progress
git stash save "WIP: adding new feature"

# List stashes
git stash list

# Apply stash
git stash apply stash@{0}

# Apply and remove stash
git stash pop
```

**4. Cherry-pick commits:**
```bash
# Apply specific commit from another branch
git cherry-pick abc123def
```

---

## Troubleshooting Workflow

### Common Issues and Solutions

#### Server Won't Start

**Problem:** `make run` fails or server crashes on startup

**Debug steps:**
```bash
# 1. Check port availability
lsof -i :8080
# If port is in use:
pkill -f server
# Or kill specific PID:
kill -9 <PID>

# 2. Check environment variables
cat .env

# 3. Run with verbose logging
go run main.go -env-file .env

# 4. Check for compilation errors
make build
# If build fails, check error output

# 5. Verify dependencies
make deps
```

#### Tests Failing

**Problem:** `make test` fails

**Debug steps:**
```bash
# 1. Run tests with verbose output
go test -v ./...

# 2. Run specific test
go test -v ./internal/handlers -run TestCalculateFlightPath

# 3. Check for race conditions
go test -race ./...

# 4. Clear test cache
go clean -testcache
go test ./...

# 5. Regenerate mocks/generated code
go generate
go test ./...
```

#### E2E Tests Failing

**Problem:** `make e2e` fails

**Debug steps:**
```bash
# 1. Ensure server is running
curl http://localhost:8080/
# Should return response, not connection refused

# 2. Check server logs
# In terminal where server is running, check for errors

# 3. Test endpoints manually
make test-case-one
make test-case-two
make test-case-three

# 4. Verify Newman installation
which newman
newman --version

# 5. Run Newman with verbose output
newman run ./test/FlightPath.postman_collection.json --verbose
```

#### Build Fails

**Problem:** `make build` fails

**Debug steps:**
```bash
# 1. Check Go version
go version
cat go.mod | grep "^go"
# Ensure versions match

# 2. Clean build cache
go clean -cache
go clean -modcache
go mod download
make build

# 3. Check for linting errors
make lint
# Fix any issues reported

# 4. Check for security issues
make sec
# Fix any issues reported

# 5. Verify all dependencies
go mod verify
go mod tidy
```

#### Docker Build Fails

**Problem:** Docker build fails

**Debug steps:**
```bash
# 1. Check Docker is running
docker ps

# 2. Check buildx builder
docker buildx ls
# If no builder:
docker buildx create --use --name builder --driver docker-container --bootstrap

# 3. Build without cache
docker build --no-cache -t flight-path:debug .

# 4. Build specific stage
docker build --target build -t flight-path:build .

# 5. Check disk space
df -h
docker system df
# Clean if needed:
docker system prune -a
```

#### Swagger Docs Not Updating

**Problem:** Changes to API not reflected in Swagger UI

**Debug steps:**
```bash
# 1. Regenerate Swagger docs
make api-docs

# 2. Check for swagger annotation errors
swag init --parseDependency -g main.go

# 3. Restart server
pkill -f server
make run

# 4. Clear browser cache
# Hard refresh: Ctrl+Shift+R (Linux/Windows) or Cmd+Shift+R (Mac)

# 5. Verify docs were generated
ls -la docs/
cat docs/swagger.json | jq .
```

#### Performance Issues

**Problem:** API responds slowly

**Debug steps:**
```bash
# 1. Run benchmarks to identify bottleneck
make bench

# 2. Profile the application
go test -cpuprofile=cpu.prof -bench=BenchmarkCalculateFlightPath
go tool pprof -http=:8081 cpu.prof

# 3. Check for memory leaks
go test -memprofile=mem.prof -bench=.
go tool pprof mem.prof

# 4. Test with different input sizes
# Create custom test with large dataset
curl -X POST http://localhost:8080/calculate \
  -H 'Content-Type: application/json' \
  -d '@large_input.json'

# 5. Check system resources
top
htop
# Look for CPU/memory usage
```

---

## Environment Setup Workflow

### Setting Up Development Environment

**1. First time setup on new machine:**
```bash
# Install Go version manager
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
source ~/.gvm/scripts/gvm

# Install Go 1.26.0
gvm install go1.26.0 --prefer-binary --with-build-tools --with-protobuf
gvm use go1.26.0 --default

# Install Node.js version manager
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc  # or ~/.zshrc

# Install Node.js LTS
nvm install --lts
nvm use --lts

# Install Newman globally
npm install --location=global newman

# Clone repository
git clone https://github.com/AndriyKalashnykov/flight-path.git
cd flight-path

# Install project dependencies
make deps

# Verify setup
which swag
which gosec
which golangci-lint
which newman
go version
node --version
npm --version
```

**2. IDE setup (optional but recommended):**
```bash
# For VS Code
code --install-extension golang.go

# For IntelliJ/GoLand - project is already configured
# Just open the project directory

# Verify IDE detects Go correctly
go env GOPATH
go env GOROOT
```

**3. Environment variables:**
```bash
# Check if .env file exists
ls -la .env

# If not, create from example (if available)
# Or create minimal .env:
cat > .env << EOF
PORT=8080
ENV=development
EOF
```

**4. Verify complete setup:**
```bash
# Run through complete workflow
make deps
make api-docs
make test
make build
make run &
sleep 5
make test-case-one
make e2e
pkill -f server
```

---

## Local Development Workflow

### Rapid Development Cycle

**1. Watch mode (manual approach):**
```bash
# Terminal 1: Run server
while true; do
  make build && ./server
  sleep 2
done

# Terminal 2: Make changes and test
# Edit code...
pkill -f server  # Server will restart via loop above
curl http://localhost:8080/calculate -X POST \
  -H 'Content-Type: application/json' \
  -d '[["SFO","EWR"]]'
```

**2. Quick iteration workflow:**
```bash
# Make a change to code
vim internal/handlers/calculate.go

# Quick validation (faster than full build)
make lint
make test

# If tests pass, try full build
make build

# Test manually
make run &
sleep 2
make test-case-one
pkill -f server
```

**3. TDD workflow:**
```bash
# 1. Write failing test
vim internal/handlers/calculate_test.go

# 2. Run test (should fail)
go test -v ./internal/handlers -run TestNewFeature

# 3. Implement feature
vim internal/handlers/calculate.go

# 4. Run test (should pass)
go test -v ./internal/handlers -run TestNewFeature

# 5. Refactor if needed
# 6. Run all tests
make test
```

---

## Hotfix Workflow

### Urgent Production Fix

**1. Create hotfix branch:**
```bash
# From main/production branch
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug-fix
```

**2. Implement fix:**
```bash
# Make minimal changes to fix the issue
vim internal/handlers/calculate.go

# Test thoroughly
make test
make build
make run &
sleep 2
make e2e
pkill -f server
```

**3. Fast-track review:**
```bash
git add .
git commit -m "fix: resolve critical path calculation bug

Fixes issue where empty segments caused panic.
Added nil check and proper error handling.
"

git push origin hotfix/critical-bug-fix
```

**4. Create PR with hotfix label:**
```bash
# Use GitHub CLI if available
gh pr create --title "HOTFIX: Critical bug fix" \
  --body "Urgent fix for production issue" \
  --label hotfix

# Or create via GitHub UI
```

**5. After merge, tag release:**
```bash
git checkout main
git pull origin main
make release
# Enter patch version: v1.2.3 -> v1.2.4
```
