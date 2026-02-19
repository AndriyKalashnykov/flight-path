---
apply: always
---

# Go Code Style Guide for flight-path

## Project Overview
This is a REST API microservice built with:
- **Echo v5** web framework
- **Swagger/Swaggo** for API documentation
- **Flight path calculation** algorithm (graph traversal)
- Focus on algorithmic efficiency and REST API design

## General Go Conventions

### Error Handling
- Always handle errors explicitly; never ignore them
- Return errors up the call stack; log only at the top level (main/handlers)
- Use descriptive error messages with context
- Use `http.StatusInternalServerError` (500) for server errors
- Use `http.StatusBadRequest` (400) for invalid input

### Code Organization
- Follow standard Go project layout:
  - `internal/` for private application code
  - `internal/handlers/` for business logic and request handlers
  - `internal/routes/` for route registration
  - `pkg/api/` for public API types and data structures
  - `docs/` for generated Swagger documentation
- Keep packages focused and cohesive
- Package names match directory names

### Naming Conventions
- Use descriptive names: `CalculateFlightPath`, `FlightSegment`, `PathResult`
- Handlers: suffix with purpose (e.g., `FlightHandler`, `HealthCheckHandler`)
- Routes: descriptive function names (e.g., `RegisterFlightRoutes`)
- Package names: short, lowercase, no underscores

## Echo v5 Specific Guidelines

### Route Registration
- Centralize route configuration in `internal/routes/`
- Use route groups for logical organization
- Register middleware appropriately
- Use Echo's built-in context (`echo.Context`)

### Handler Pattern
```go
func HandlerName(c echo.Context) error {
    // 1. Parse/validate input
    // 2. Call business logic
    // 3. Return JSON response
    return c.JSON(http.StatusOK, result)
}
```

### Error Responses
- Use consistent error response format
- Return appropriate HTTP status codes
- Include descriptive error messages
- Example: `c.JSON(http.StatusInternalServerError, map[string]string{"error": "message"})`

## Swagger/Swaggo Guidelines

### Swagger Annotations
- Document all public endpoints with Swagger comments
- Use proper tags for grouping endpoints
- Document request/response models
- Include operation IDs for clarity

### Swagger Comment Format
```go
// HandlerName godoc
// @Summary Brief summary
// @Description Detailed description
// @Tags TagName
// @ID operation-id
// @Accept json
// @Produce json
// @Param name body Type true "Description"
// @Success 200 {object} ResponseType
// @Failure 400 {object} map[string]interface{}
// @Failure 500 {object} map[string]interface{}
// @Router /path [post]
```

### Documentation Generation
- Always run `make api-docs` after changing Swagger comments
- Don't manually edit generated files in `docs/`
- Swagger config is in `main.go` with `@` directives
- Keep `docs/swagger.json` updated in version control

## Algorithm & Business Logic

### Flight Path Calculation
- Keep algorithm logic in `internal/handlers/` package
- Use graph data structures (adjacency list/map)
- Handle edge cases:
  - Empty flight segments
  - Single flight
  - Disconnected flights (invalid path)
  - Circular routes
- Optimize for readability first, performance second
- Document algorithmic complexity in comments

### Input Validation
- Validate flight segment format: `[["SRC", "DST"], ...]`
- Check for empty arrays
- Validate airport codes (3-letter uppercase)
- Return clear error messages for invalid input

### Data Structures
- Use `[][]string` for flight segments input
- Use `[]string` for flight path output (start, end airports)
- Keep models in `pkg/api/` for reusability

## Testing

### Test Organization
- Unit tests in `*_test.go` files
- Benchmark tests in `*_bench_test.go` files
- Integration tests for full API flow
- Use table-driven tests for multiple scenarios

### Running Tests
- `make test` - Run all tests
- `make bench` - Run benchmarks
- `make bench-save` - Save benchmark results
- `make bench-compare` - Compare benchmark results

### Test Coverage
- Aim for high coverage on business logic
- Test edge cases and error conditions
- Test all REST endpoints

## Build & Development

### Makefile Targets
- `make deps` - Install required tools (swag, golangci-lint, gosec)
- `make api-docs` - Generate Swagger documentation
- `make lint` - Run linter
- `make test` - Run tests
- `make build` - Build server binary
- `make run` - Build and run server
- `make e2e` - Run Postman/Newman tests
- `make test-case-one/two/three` - Run specific test cases

### Development Workflow
1. Make code changes
2. Run `make api-docs` if Swagger comments changed
3. Run `make lint` to check code quality
4. Run `make test` to verify functionality
5. Run `make build` to ensure compilation
6. Test manually: `make run` then `make test-case-*`

### Dependencies
- Use `go.mod` with Go 1.26.0+
- Run `make update` to update dependencies
- Use `GOFLAGS=-mod=mod` for module-aware builds
- Keep dependencies minimal

### Key Dependencies
- `github.com/labstack/echo/v5` - Web framework
- `github.com/swaggo/echo-swagger` - Swagger UI integration
- `github.com/swaggo/swag` - Swagger documentation generator
- `github.com/joho/godotenv` - Environment variable management

## Code Quality

### Formatting
- Use `gofmt` (automatically applied)
- Maintain consistent indentation (tabs)
- Keep lines reasonably short (< 120 chars)

### Linting & Security
- Run `make lint` before committing (golangci-lint)
- Run `make critic` for code criticism (go-critic)
- Run `make sec` for security checks (gosec)
- Fix all critical issues before merging

### Best Practices
- Avoid global state
- Use dependency injection
- Keep functions small and focused
- Write self-documenting code
- Add comments for complex logic (especially algorithms)
- Use constants for magic values
- Document algorithmic complexity for non-trivial functions

### Performance
- Benchmark critical paths with `make bench`
- Save benchmarks with `make bench-save` before optimization
- Compare results with `make bench-compare` after changes
- Optimize only when necessary (measure first)

## REST API Design

### Endpoint Structure
- Use RESTful conventions
- POST for operations that change state or perform calculations
- Use descriptive paths (e.g., `/calculate` for flight path calculation)
- Use proper HTTP methods and status codes

### Request/Response Format
- Accept and return JSON
- Use consistent response structures
- Include proper Content-Type headers
- Document all fields in Swagger

### Error Handling
- Return appropriate HTTP status codes:
  - 200: Success
  - 400: Bad request (invalid input)
  - 500: Internal server error
- Include descriptive error messages
- Use consistent error response format

## Version Control

### Versioning
- Version info in `pkg/api/version.txt`
- Use `make release` to create and push tags
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Update version before releases

### Commit Messages
- Follow conventional commit format
- Keep commits atomic and focused
- Include issue/PR references when relevant

## CI/CD

### GitHub CI Workflow
- Automated on push/PR to main branch
- Steps: checkout, setup, deps, test, build, run, e2e tests
- Must pass all checks before merge
- Newman/Postman tests verify API functionality

### Local Pre-commit Checks
Before committing:
- [ ] `make lint` passes
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] Manual testing done
- [ ] Swagger docs updated if API changed
