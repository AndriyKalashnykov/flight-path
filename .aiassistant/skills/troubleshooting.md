---
description: Common issues and their solutions for the flight-path REST API project
---

# Troubleshooting Guide

## Build Issues

### Issue: Build Fails with Missing Dependencies

**Symptoms:**
```
package github.com/swaggo/swag is not in GOROOT
cannot find package
```

**Solution:**
```bash
make deps      # Install all required tools
go mod tidy    # Clean up go.mod and go.sum
make build     # Try building again
```

**Prevention:**
- Always run `make deps` after cloning the repository
- Run `go mod tidy` after adding/removing dependencies
- Check `go.mod` for correct Go version

---

### Issue: Swagger Generation Fails

**Symptoms:**
```
swag: command not found
# or
Failed to generate swagger docs
```

**Solution:**
```bash
# Install swag
go install github.com/swaggo/swag/cmd/swag@latest

# Verify installation
which swag
swag --version

# Regenerate docs
make api-docs
```

**Common Causes:**
- `$GOPATH/bin` not in PATH
- Swagger comments have syntax errors
- Missing `@` directives in main.go

**Prevention:**
- Always run `make api-docs` after changing Swagger comments
- Validate Swagger syntax in comments
- Keep Swagger annotations close to handlers

---

### Issue: Linter Errors

**Symptoms:**
```
golangci-lint: command not found
# or
make lint fails with code style issues
```

**Solution:**
```bash
# Install golangci-lint
curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $(go env GOPATH)/bin

# Run linter
make lint

# Fix issues reported
# Common fixes:
# - Remove unused variables
# - Add error handling
# - Fix formatting
```

**Prevention:**
- Run `make lint` before committing
- Configure IDE to run golangci-lint on save
- Follow conventions in `golang.md`

---

## Runtime Issues

### Issue: Port 8080 Already in Use

**Symptoms:**
```
listen tcp :8080: bind: address already in use
```

**Solution:**
```bash
# Find and kill process on port 8080
lsof -ti:8080 | xargs kill -9

# Or kill by process name
pkill -f "flight-path/server"
pkill -f "./server"

# Restart server
make run
```

**Prevention:**
- Always stop the server before restarting: `Ctrl+C`
- Use a different port if 8080 is needed elsewhere
- Check for orphaned processes: `ps aux | grep server`

---

### Issue: API Returns 404 Not Found

**Symptoms:**
```
curl http://localhost:8080/calculate
# Returns: 404 page not found
```

**Diagnosis:**
1. Check if server is running:
   ```bash
   curl http://localhost:8080/
   # Should return something (healthcheck or welcome message)
   ```

2. Check routes are registered:
   ```bash
   # Look for route registration in logs when server starts
   # Or check routes/*.go files
   ```

3. Verify endpoint path:
   ```bash
   curl -X POST http://localhost:8080/calculate
   # Must use POST, not GET
   ```

**Solution:**
- Ensure routes are registered in `internal/routes/`
- Use correct HTTP method (POST for /calculate)
- Check Swagger docs: http://localhost:8080/swagger/index.html

---

### Issue: API Returns 500 Internal Server Error

**Symptoms:**
```
{"error": "internal server error"}
```

**Diagnosis:**
1. Check server logs in terminal where `make run` was executed
2. Look for error messages or stack traces
3. Test with minimal input:
   ```bash
   curl -X POST http://localhost:8080/calculate \
     -H 'Content-Type: application/json' \
     -d '[["SFO", "EWR"]]'
   ```

**Common Causes:**
- Algorithm error with specific input
- Panic in handler code
- Unhandled edge case

**Solution:**
- Read error message in logs
- Add error handling for specific case
- Write test to reproduce the issue
- Fix bug and verify with test

---

### Issue: Invalid JSON Input Crashes Server

**Symptoms:**
- Server panics or returns 500 instead of 400
- No graceful error handling

**Solution:**
Add input validation:
```go
var segments [][]string
if err := c.Bind(&segments); err != nil {
    return c.JSON(http.StatusBadRequest, map[string]string{
        "error": "invalid JSON format",
    })
}

if err := ValidateFlightSegments(segments); err != nil {
    return c.JSON(http.StatusBadRequest, map[string]string{
        "error": err.Error(),
    })
}
```

**Prevention:**
- Always validate input before processing
- Return 400 for invalid input, not 500
- Test with malformed inputs

---

## Algorithm Issues

### Issue: Flight Path Calculation Returns Wrong Result

**Symptoms:**
- Test cases fail
- Unexpected output for valid input
- Edge cases not handled

**Diagnosis:**
1. Test with simple case:
   ```bash
   make test-case-one  # Single flight
   ```

2. Test with multiple cases:
   ```bash
   make test-case-two    # Two segments
   make test-case-three  # Complex path
   ```

3. Run unit tests:
   ```bash
   make test
   ```

**Solution:**
- Add test case that fails
- Debug algorithm step-by-step
- Check for edge cases:
  - Empty input
  - Single flight
  - Disconnected flights
  - Circular paths
- Fix algorithm and verify tests pass

---

### Issue: Performance Degradation

**Symptoms:**
- API becomes slow with large inputs
- Tests timeout
- High CPU usage

**Diagnosis:**
```bash
# Run benchmarks
make bench

# Save baseline
make bench-save

# After changes, compare
make bench-save
make bench-compare
```

**Solution:**
1. Identify bottleneck (profiling)
2. Optimize algorithm complexity
3. Use appropriate data structures
4. Benchmark before and after

**Example:**
```bash
# Before optimization
make bench-save

# Make changes to use map instead of nested loops

# After optimization
make bench-save

# Compare results
make bench-compare
# Should show improvement
```

---

## Test Issues

### Issue: Tests Fail After Changes

**Symptoms:**
```
FAIL: TestCalculateFlightPath
expected [SFO EWR], got [EWR SFO]
```

**Solution:**
1. Read test failure message carefully
2. Fix the code or update the test (if test is wrong)
3. Run tests again:
   ```bash
   make test
   ```

**Prevention:**
- Run tests before committing
- Write tests for new features
- Don't skip failing tests

---

### Issue: E2E Tests Fail

**Symptoms:**
```bash
make e2e
# Newman tests fail
# Connection refused or timeout
```

**Solution:**
```bash
# Ensure server is running
make run &

# Wait for server to start
sleep 2

# Run E2E tests
make e2e

# Stop server
pkill -f server
```

**Prevention:**
- Always start server before E2E tests
- Wait for server to be ready
- Check port is not blocked by firewall

---

## Swagger Documentation Issues

### Issue: Swagger UI Shows Outdated API

**Symptoms:**
- Changed API but Swagger UI shows old version
- New endpoints not appearing

**Solution:**
```bash
# Regenerate Swagger docs
make api-docs

# Restart server
make run

# Clear browser cache and reload
# Or use curl to verify:
curl http://localhost:8080/swagger/doc.json
```

**Prevention:**
- Run `make api-docs` after changing Swagger comments
- Include `make api-docs` in `make build`
- Never manually edit `docs/` files

---

### Issue: Swagger Comments Syntax Error

**Symptoms:**
```
Error: parsing swagger comments failed
```

**Solution:**
- Check Swagger comment syntax
- Common issues:
  - Missing `@` symbol
  - Wrong parameter format
  - Incorrect type references
- Fix syntax and run `make api-docs`

**Example:**
```go
// ✅ CORRECT
// @Summary Calculate flight path
// @Param flightSegments body [][]string true "Flight segments"
// @Success 200 {array} string

// ❌ WRONG
// Summary Calculate flight path (missing @)
// Param flightSegments true "Flight segments" (missing type)
```

---

## Debugging Commands

### Check Server Status
```bash
# Is server running?
ps aux | grep -E "(server|flight-path)"

# Is port in use?
lsof -i:8080

# Test server responds
curl http://localhost:8080/
```

### Test API Manually
```bash
# Test case 1
curl -X POST http://localhost:8080/calculate \
  -H 'Content-Type: application/json' \
  -d '[["SFO", "EWR"]]'

# Test case 2
curl -X POST http://localhost:8080/calculate \
  -H 'Content-Type: application/json' \
  -d '[["ATL", "EWR"], ["SFO", "ATL"]]'

# Invalid input (should return 400)
curl -X POST http://localhost:8080/calculate \
  -H 'Content-Type: application/json' \
  -d 'invalid'
```

### Check Dependencies
```bash
# Go version
go version

# Installed tools
which swag
which golangci-lint
which gosec
which newman

# Go environment
go env GOPATH
go env GOROOT
```

### Clean Build
```bash
# Clean cache
go clean -cache -modcache -i -r

# Remove binary
rm -f server

# Rebuild
make deps
make build
```

---

## Prevention Checklist

Before coding:
- [ ] Read `golang.md` for conventions
- [ ] Run `make deps` to ensure tools are installed
- [ ] Review existing code patterns

Before testing:
- [ ] Server is not running (to avoid port conflict)
- [ ] Run `make build` to ensure code compiles
- [ ] Run `make test` to verify functionality

Before committing:
- [ ] Run `make lint` - no errors
- [ ] Run `make critic` - no critical issues
- [ ] Run `make sec` - no security issues
- [ ] Run `make test` - all tests pass
- [ ] Run `make api-docs` - Swagger docs updated
- [ ] Manual test with `make test-case-*` - API works
- [ ] Run `make e2e` - E2E tests pass

---

## Getting Help

### Useful Resources
- [Echo v5 Documentation](https://echo.labstack.com/)
- [Swagger/Swaggo Documentation](https://github.com/swaggo/swag)
- [Go Documentation](https://go.dev/doc/)

### Debug Mode
Add debug logging:
```go
import "log"

log.Printf("DEBUG: segments = %+v", segments)
log.Printf("DEBUG: result = %+v", result)
```

### Verbose Testing
```bash
go test -v ./...           # Verbose test output
go test -v -run TestName   # Run specific test with output
```
