---
apply: always
---

# Testing Guidelines

## Testing Philosophy

- Tests are first-class code - maintain them with the same care as production code
- Write tests before or alongside implementation (TDD preferred)
- Tests should be fast, isolated, and deterministic
- Every bug fix should include a test that would have caught it
- Benchmark performance-critical code paths

## Running Tests

### Standard Workflow
```bash
make test          # Run all tests
go test ./...      # Run tests directly
go test -v ./...   # Verbose output
go test -run TestName  # Run specific test
```

### Test Coverage
```bash
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Benchmarks
```bash
make bench              # Run benchmarks
make bench-save         # Save benchmark results with timestamp
make bench-compare      # Compare latest two benchmarks
make bench-compare OLD=file1.txt NEW=file2.txt  # Compare specific files
```

## Test Organization

### File Structure
- Test files: `*_test.go` in same package
- Benchmark files: `*_bench_test.go` for benchmark tests
- Package naming: `package mypackage` (white-box) or `package mypackage_test` (black-box)
- Prefer white-box tests for unit tests, black-box for integration tests

### Test Function Naming
```go
func TestFunctionName(t *testing.T)           // Basic test
func TestFunctionName_Scenario(t *testing.T)  // Specific scenario
func TestFunctionName_ErrorCase(t *testing.T) // Error cases
```

Examples:
- `TestCalculateFlightPath`
- `TestCalculateFlightPath_EmptyInput`
- `TestCalculateFlightPath_SingleFlight`
- `TestCalculateFlightPath_DisconnectedFlights`
- `TestFlightHandler_Success`
- `TestFlightHandler_InvalidJSON`

## Test Patterns

### Table-Driven Tests
Preferred pattern for testing multiple scenarios:

```go
func TestCalculateFlightPath(t *testing.T) {
    tests := []struct {
        name     string
        segments [][]string
        want     []string
        wantErr  bool
    }{
        {
            name:     "single flight",
            segments: [][]string{{"SFO", "EWR"}},
            want:     []string{"SFO", "EWR"},
            wantErr:  false,
        },
        {
            name:     "two flights",
            segments: [][]string{{"ATL", "EWR"}, {"SFO", "ATL"}},
            want:     []string{"SFO", "EWR"},
            wantErr:  false,
        },
        {
            name:     "empty input",
            segments: [][]string{},
            want:     nil,
            wantErr:  true,
        },
        {
            name:     "disconnected flights",
            segments: [][]string{{"SFO", "ATL"}, {"JFK", "LAX"}},
            want:     nil,
            wantErr:  true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := CalculateFlightPath(tt.segments)
            if (err != nil) != tt.wantErr {
                t.Errorf("CalculateFlightPath() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("CalculateFlightPath() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

### Subtests
Use `t.Run()` for organizing related tests:

```go
func TestFlightAPI(t *testing.T) {
    t.Run("CalculatePath", func(t *testing.T) {
        // test path calculation
    })

    t.Run("Validation", func(t *testing.T) {
        // test input validation
    })

    t.Run("ErrorHandling", func(t *testing.T) {
        // test error cases
    })
}
```

## Testing REST API Handlers

### Echo Handler Testing
```go
func TestFlightHandler(t *testing.T) {
    e := echo.New()
    req := httptest.NewRequest(http.MethodPost, "/calculate", strings.NewReader(`[["SFO", "EWR"]]`))
    req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
    rec := httptest.NewRecorder()
    c := e.NewContext(req, rec)

    if err := FlightHandler(c); err != nil {
        t.Fatalf("handler returned error: %v", err)
    }

    if rec.Code != http.StatusOK {
        t.Errorf("expected status 200, got %d", rec.Code)
    }

    var result []string
    if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
        t.Fatalf("failed to unmarshal response: %v", err)
    }

    expected := []string{"SFO", "EWR"}
    if !reflect.DeepEqual(result, expected) {
        t.Errorf("expected %v, got %v", expected, result)
    }
}
```

### Testing Error Responses
```go
func TestFlightHandler_InvalidInput(t *testing.T) {
    e := echo.New()
    req := httptest.NewRequest(http.MethodPost, "/calculate", strings.NewReader(`invalid json`))
    req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
    rec := httptest.NewRecorder()
    c := e.NewContext(req, rec)

    err := FlightHandler(c)
    if err != nil {
        // Echo handlers can return errors for middleware to handle
        httpErr, ok := err.(*echo.HTTPError)
        if !ok || httpErr.Code != http.StatusBadRequest {
            t.Errorf("expected HTTPError 400, got %v", err)
        }
    } else if rec.Code != http.StatusBadRequest {
        t.Errorf("expected status 400, got %d", rec.Code)
    }
}
```

## Testing Best Practices

### Input Validation Testing
Test all validation rules:
```go
func TestValidateFlightSegments(t *testing.T) {
    tests := []struct {
        name     string
        segments [][]string
        wantErr  bool
        errMsg   string
    }{
        {
            name:     "valid segments",
            segments: [][]string{{"SFO", "EWR"}, {"ATL", "SFO"}},
            wantErr:  false,
        },
        {
            name:     "empty segments",
            segments: [][]string{},
            wantErr:  true,
            errMsg:   "empty",
        },
        {
            name:     "segment with wrong size",
            segments: [][]string{{"SFO"}},
            wantErr:  true,
            errMsg:   "expected 2 elements",
        },
        {
            name:     "invalid airport code",
            segments: [][]string{{"SF", "EWR"}},
            wantErr:  true,
            errMsg:   "invalid airport code",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateFlightSegments(tt.segments)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateFlightSegments() error = %v, wantErr %v", err, tt.wantErr)
            }
            if err != nil && tt.errMsg != "" && !strings.Contains(err.Error(), tt.errMsg) {
                t.Errorf("error message should contain %q, got %q", tt.errMsg, err.Error())
            }
        })
    }
}
```

### Algorithm Testing
Test edge cases thoroughly:
```go
func TestFlightPathAlgorithm(t *testing.T) {
    tests := []struct {
        name     string
        segments [][]string
        want     []string
        wantErr  bool
    }{
        {
            name:     "simple path",
            segments: [][]string{{"A", "B"}},
            want:     []string{"A", "B"},
        },
        {
            name:     "linear path",
            segments: [][]string{{"B", "C"}, {"A", "B"}, {"C", "D"}},
            want:     []string{"A", "D"},
        },
        {
            name:     "circular path should fail",
            segments: [][]string{{"A", "B"}, {"B", "C"}, {"C", "A"}},
            wantErr:  true,
        },
        {
            name:     "disconnected path",
            segments: [][]string{{"A", "B"}, {"C", "D"}},
            wantErr:  true,
        },
        {
            name:     "empty",
            segments: [][]string{},
            wantErr:  true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := CalculateFlightPath(tt.segments)
            if (err != nil) != tt.wantErr {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if !tt.wantErr && !reflect.DeepEqual(got, tt.want) {
                t.Errorf("got %v, want %v", got, tt.want)
            }
        })
    }
}
```

### Test Cleanup
```go
func TestSomething(t *testing.T) {
    // Setup
    cleanup := setupTest(t)
    defer cleanup()

    // Or use t.Cleanup
    t.Cleanup(func() {
        // cleanup code
    })
}
```

### Parallel Tests
```go
func TestParallel(t *testing.T) {
    t.Parallel() // Mark test as safe to run in parallel

    tests := []struct{
        name string
    }{
        {name: "test1"},
        {name: "test2"},
    }

    for _, tt := range tests {
        tt := tt // Capture range variable
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // test code
        })
    }
}
```

## Benchmarking

### Writing Benchmarks
```go
func BenchmarkCalculateFlightPath(b *testing.B) {
    segments := [][]string{
        {"IND", "EWR"},
        {"SFO", "ATL"},
        {"GSO", "IND"},
        {"ATL", "GSO"},
    }

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, err := CalculateFlightPath(segments)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkCalculateFlightPath_LargeInput(b *testing.B) {
    // Create large input
    segments := make([][]string, 1000)
    for i := 0; i < 1000; i++ {
        segments[i] = []string{fmt.Sprintf("A%d", i), fmt.Sprintf("A%d", i+1)}
    }

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, err := CalculateFlightPath(segments)
        if err != nil {
            b.Fatal(err)
        }
    }
}
```

### Benchmark Comparison Workflow
```bash
# Before optimization
make bench-save

# Make changes to optimize

# After optimization
make bench-save

# Compare results
make bench-compare
# Output shows performance difference:
# name                          old time/op    new time/op    delta
# CalculateFlightPath-8         1.23µs ± 2%    0.98µs ± 1%   -20.33%
```

## Integration Tests

### End-to-End API Tests
Use Postman/Newman for E2E tests:
```bash
make e2e  # Run Newman collection
```

Test collection should cover:
- All API endpoints
- Valid inputs
- Invalid inputs
- Error responses
- Edge cases

### Manual Test Cases
```bash
make test-case-one    # Simple flight
make test-case-two    # Two flight segments
make test-case-three  # Complex path
```

## Test Documentation

### Test Comments
```go
// TestCalculateFlightPath_EmptyInput verifies that the algorithm
// returns an error when given empty flight segments, preventing
// invalid processing and ensuring proper error handling.
func TestCalculateFlightPath_EmptyInput(t *testing.T) {
    // ...
}
```

### Example Tests
Use Example tests for documentation:
```go
func ExampleCalculateFlightPath() {
    segments := [][]string{
        {"SFO", "ATL"},
        {"ATL", "EWR"},
    }

    result, err := CalculateFlightPath(segments)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println(result)
    // Output: [SFO EWR]
}
```

## What to Test

### Always Test:
- Public API functions and methods
- All REST endpoint handlers
- Algorithm logic (especially edge cases)
- Input validation
- Error conditions and edge cases
- Boundary conditions (empty, nil, single element, large input)

### Consider Testing:
- Private functions with complex logic
- Performance-critical paths (benchmarks)
- Different input orderings
- Various error scenarios

### Don't Test:
- Generated code (`docs/`)
- Trivial getters/setters
- Third-party libraries
- Code that's only glue (no logic)

## Test Quality Checklist

- [ ] Test names clearly describe what is being tested
- [ ] Tests are independent (can run in any order)
- [ ] Tests clean up resources (defer, t.Cleanup)
- [ ] Error messages are descriptive
- [ ] Table-driven tests used for multiple scenarios
- [ ] All edge cases covered
- [ ] Tests are fast (< 1 second for unit tests)
- [ ] Benchmarks exist for critical paths
- [ ] Integration tests verify full API flow

## Common Pitfalls

### Avoid:
- Tests that depend on external services without fallback
- Tests with sleep/timing dependencies
- Sharing state between tests
- Testing implementation details instead of behavior
- Ignoring test failures or flaky tests
- Not testing error cases
- Not benchmarking before optimizing

### Remember:
- Use `t.Helper()` in helper functions for better error reporting
- Capture range variables in parallel subtests
- Always defer cleanup functions
- Test with realistic data
- Benchmark before and after optimizations
- Run `make test` before committing
- Use `make e2e` to verify API contract
