# Project Conventions

## Handler Pattern

Handlers are methods on `Handler` struct in `internal/handlers/`. Keep them thin:

```go
func (h Handler) MyEndpoint(c *echo.Context) error {
    // 1. Bind input
    // 2. Validate (return 400 on failure)
    // 3. Call business logic (return 500 on failure)
    // 4. Return JSON response
}
```

Business logic (algorithms) stays in `internal/handlers/api.go` — separate from HTTP concerns.
Routes in `internal/routes/` receive `*handlers.Handler` and wire methods.

## Swagger Annotations

Required on all public endpoints. Run `make api-docs` after changes. Never edit `docs/` manually.

```go
// MyEndpoint godoc
// @Summary Brief summary
// @Description Detailed description
// @Tags TagName
// @ID my-endpoint
// @Accept json
// @Produce json
// @Param input body Type true "Description"
// @Success 200 {object} ResponseType
// @Failure 400 {object} map[string]interface{}
// @Failure 500 {object} map[string]interface{}
// @Router /path [method]
```

## Error Handling

- Return errors up the stack; log only at handler level
- 400 for invalid input/validation, 500 for unexpected server errors
- Consistent JSON error format: `{"error": "descriptive message"}`
- Validate inputs before processing; fail fast

## Testing

- **Table-driven tests** preferred for multiple scenarios
- **Benchmarks** for critical paths: `make bench-save` before/after optimization, `make bench-compare`
- Test edge cases: empty input, single flight, disconnected flights, circular paths
- Run `make test` before and after any refactoring

## Input Validation

- Flight segments must be non-empty
- Each segment: exactly 2 airports `[source, destination]`
- Airport codes: 3-letter uppercase (IATA)
- Source and destination cannot be the same
- Flights must form a connected path

## Data Types

- Input: `[][]string` (flight segments)
- Output: `[]string` (start and end airports)
- Internal: `api.Flight` struct with `Start`/`End` fields (`pkg/api/data.go`)

## Code Style

- `gofmt` formatting, lines < 120 chars
- Descriptive naming: `FlightCalculate`, `ServerHealthCheck`, `FindItinerary`
- `GOFLAGS=-mod=mod` for builds
- Conventional commits: `feat:`, `fix:`, `perf:`, `chore:`, `refactor:`, `test:`

## Refactoring

- Write tests first; don't change behavior during refactoring
- Benchmark before optimizing — measure, don't guess
- Don't over-engineer; prefer readability over cleverness
- Keep generated code (`docs/`) untouched — regenerate with `make api-docs`

## Pre-commit Checklist

```bash
make lint && make critic && make sec && make test && make api-docs && make build
```
