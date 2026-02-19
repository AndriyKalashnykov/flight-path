---
apply: always
---

# Refactoring Guidelines

## When to Refactor

### Always Refactor When:
- Adding new features that would duplicate existing code
- Code violates project conventions in `golang.md`
- Functions exceed ~50 lines or have deep nesting (>3 levels)
- Business logic is mixed with handler/routing code
- Tests are difficult to write due to tight coupling
- Same pattern is repeated 3+ times (Rule of Three)
- Algorithm complexity can be improved without sacrificing readability

### Consider Refactoring When:
- Benchmark results show performance issues
- Error handling is inconsistent
- Dependencies are tightly coupled
- Code is difficult to understand or maintain
- Algorithm can be optimized (but benchmark first!)

## Refactoring Principles

### 1. Test First
- Ensure tests exist before refactoring
- Run `make test` before and after changes
- Add tests if coverage is missing
- Benchmark before optimizing: `make bench-save`

### 2. Small Steps
- Make incremental changes
- Commit after each logical refactoring step
- Keep the code working at each step
- Run tests frequently

### 3. Don't Change Behavior
- Refactoring should not alter functionality
- Only improve structure, readability, or performance
- Bug fixes are separate from refactoring
- Verify with tests and manual testing

## Common Refactoring Patterns

### Extract Function
When a function does too much:
```go
// Before
func FlightHandler(c echo.Context) error {
    var segments [][]string
    if err := c.Bind(&segments); err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid input"})
    }

    // Complex algorithm logic here...
    graph := make(map[string]string)
    for _, seg := range segments {
        graph[seg[0]] = seg[1]
    }
    // More logic...

    return c.JSON(http.StatusOK, result)
}

// After - extract algorithm
func FlightHandler(c echo.Context) error {
    var segments [][]string
    if err := c.Bind(&segments); err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid input"})
    }

    result, err := CalculateFlightPath(segments)
    if err != nil {
        return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
    }

    return c.JSON(http.StatusOK, result)
}

func CalculateFlightPath(segments [][]string) ([]string, error) {
    // Algorithm logic here
}
```

### Introduce Service Layer
Move business logic from handlers to service packages:
```go
// internal/service/flight.go
type FlightService struct {
    // dependencies if needed
}

func NewFlightService() *FlightService {
    return &FlightService{}
}

func (s *FlightService) CalculatePath(segments [][]string) ([]string, error) {
    // Business logic here
}

// internal/handlers/flight.go
func FlightHandler(service *FlightService) echo.HandlerFunc {
    return func(c echo.Context) error {
        var segments [][]string
        if err := c.Bind(&segments); err != nil {
            return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid input"})
        }

        result, err := service.CalculatePath(segments)
        if err != nil {
            return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
        }

        return c.JSON(http.StatusOK, result)
    }
}
```

### Introduce Constants
Replace magic values:
```go
// Before
if len(segment) != 2 {
    return nil, errors.New("invalid segment")
}

// After
const (
    FlightSegmentSize = 2
    AirportCodeLength = 3
)

if len(segment) != FlightSegmentSize {
    return nil, fmt.Errorf("invalid segment: expected %d elements", FlightSegmentSize)
}
```

### Introduce Validation Functions
Extract validation logic:
```go
// Before
func Handler(c echo.Context) error {
    var segments [][]string
    if err := c.Bind(&segments); err != nil {
        return c.JSON(400, map[string]string{"error": "invalid"})
    }
    if len(segments) == 0 {
        return c.JSON(400, map[string]string{"error": "empty"})
    }
    // ... more validation
}

// After
func ValidateFlightSegments(segments [][]string) error {
    if len(segments) == 0 {
        return errors.New("flight segments cannot be empty")
    }

    for i, seg := range segments {
        if len(seg) != FlightSegmentSize {
            return fmt.Errorf("segment %d: expected %d airports, got %d", i, FlightSegmentSize, len(seg))
        }
        if !isValidAirportCode(seg[0]) || !isValidAirportCode(seg[1]) {
            return fmt.Errorf("segment %d: invalid airport code", i)
        }
    }

    return nil
}

func Handler(c echo.Context) error {
    var segments [][]string
    if err := c.Bind(&segments); err != nil {
        return c.JSON(400, map[string]string{"error": "invalid JSON"})
    }
    if err := ValidateFlightSegments(segments); err != nil {
        return c.JSON(400, map[string]string{"error": err.Error()})
    }
    // ... process valid segments
}
```

### Dependency Injection
Make dependencies explicit and testable:
```go
// Before
func NewHandler() echo.HandlerFunc {
    return func(c echo.Context) error {
        // handler uses hardcoded dependencies
    }
}

// After - inject dependencies
type Dependencies struct {
    FlightService *FlightService
    Logger        *Logger
}

func NewHandler(deps *Dependencies) echo.HandlerFunc {
    return func(c echo.Context) error {
        // handler uses injected dependencies
    }
}
```

## Project-Specific Guidelines

### REST API Handlers
- Keep handlers thin - delegate to service/logic layers
- Handlers should only handle:
  - Request binding and validation
  - Calling service methods
  - Response formatting
  - Error handling/HTTP status codes
- Never put algorithm logic directly in handlers

### Algorithm Optimization
**Before optimizing:**
1. Run `make bench-save` to save baseline
2. Profile to identify bottlenecks
3. Optimize the hot path only
4. Run `make bench-save` again
5. Compare with `make bench-compare`

**Optimization priorities:**
1. Algorithmic complexity (O(n) vs O(n²))
2. Data structure choice (map vs slice)
3. Memory allocations
4. Micro-optimizations (last resort)

**Example:**
```go
// Before - O(n²) lookup
func findStart(segments [][]string) string {
    for _, seg := range segments {
        isStart := true
        for _, check := range segments {
            if check[1] == seg[0] {
                isStart = false
                break
            }
        }
        if isStart {
            return seg[0]
        }
    }
    return ""
}

// After - O(n) with map
func findStart(segments [][]string) string {
    destinations := make(map[string]bool)
    sources := make(map[string]bool)

    for _, seg := range segments {
        destinations[seg[1]] = true
        sources[seg[0]] = true
    }

    for src := range sources {
        if !destinations[src] {
            return src
        }
    }
    return ""
}
```

### Error Handling
- Use consistent error patterns
- Wrap errors with context: `fmt.Errorf("failed to calculate path: %w", err)`
- Return errors with appropriate HTTP status
- Validate inputs before processing
- Provide helpful error messages for users

### Swagger Documentation
- Extract complex request/response types to `pkg/api/`
- Document types in separate files
- Regenerate docs after changes: `make api-docs`
- Keep Swagger comments close to handlers

## What NOT to Refactor

### Don't Touch:
- Generated code in `docs/` - regenerate with `make api-docs` instead
- Working code without tests (write tests first)
- Code you don't understand (study it first)
- External dependencies (upgrade/replace instead)

### Avoid Over-Engineering:
- Don't create abstractions for single use cases
- Don't prematurely optimize (benchmark first)
- Keep it simple - prefer clarity over cleverness
- Don't add unnecessary layers for a simple API

## Refactoring Checklist

Before committing refactored code:
- [ ] All tests pass (`make test`)
- [ ] Code follows `golang.md` conventions
- [ ] No behavior changes (unless intended)
- [ ] Error handling is consistent
- [ ] Functions are focused and small
- [ ] Magic values replaced with constants
- [ ] Dependencies are injected
- [ ] Swagger docs updated (`make api-docs`)
- [ ] Lint passes (`make lint`)
- [ ] Security check passes (`make sec`)
- [ ] Benchmarks improved or unchanged (`make bench-compare`)
- [ ] Code is more maintainable than before
- [ ] Commit message explains the refactoring

## When in Doubt
- Prefer readability over cleverness
- Benchmark before optimizing
- Keep functions small and focused
- Follow existing patterns in the codebase
- Ask for review on significant changes
- Test with actual API calls: `make test-case-*`
