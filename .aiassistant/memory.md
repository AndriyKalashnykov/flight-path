---
description: Project-specific context and knowledge base
---

# Project Memory

## Project Overview

**Name**: flight-path
**Type**: REST API Microservice
**Purpose**: Calculate flight paths from unordered flight segments
**Primary Language**: Go 1.26.0
**Web Framework**: Echo v5
**Documentation**: Swagger/Swaggo

## Core Algorithm

### Problem Statement
Given a list of flight segments (source → destination pairs) that may be unordered, determine the complete flight path (starting airport → ending airport).

### Example
```
Input:  [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
Output: ["SFO", "EWR"]
Path:   SFO → ATL → GSO → IND → EWR
```

### Algorithm Approach
- Build graph (adjacency list/map) from flight segments
- Find starting airport (has no incoming edge)
- Traverse graph to find ending airport (has no outgoing edge)
- Handle edge cases: empty input, disconnected flights, circular paths

### Complexity
- Time: O(n) where n = number of flight segments
- Space: O(n) for graph storage

## Project Structure

```
flight-path/
├── main.go                          # Entry point, server setup, Swagger config
├── internal/handlers/               # Business logic and handlers
│   ├── handlers.go                  # Flight path calculation logic
│   ├── flight.go                    # Flight endpoint handler
│   ├── healthcheck.go               # Health check handler
│   ├── api.go                       # API utilities
│   └── api_bench_test.go            # Benchmark tests
├── internal/routes/                 # Route registration
│   ├── flight.go                    # Flight routes
│   ├── healthcheck.go               # Health routes
│   └── swagger.go                   # Swagger routes
├── pkg/api/                         # Public API types
│   └── data.go                      # Data structures
├── docs/                            # Generated Swagger docs
└── test/                            # E2E test collections
    └── FlightPath.postman_collection.json
```

## Key Design Decisions

### 1. Handler Organization
- Handlers in `internal/handlers/` contain business logic
- Route registration separated in `internal/routes/`
- Clear separation between routing and logic

### 2. Algorithm Implementation
- Uses map-based graph for O(1) lookups
- Single-pass algorithm for efficiency
- Comprehensive edge case handling

### 3. API Design
- Single POST endpoint: `/calculate`
- Accepts: `[][]string` (array of [source, destination] pairs)
- Returns: `[]string` (array of [start, end] airports)
- RESTful error handling with appropriate status codes

### 4. Testing Strategy
- Unit tests for algorithm logic
- Benchmark tests for performance tracking
- E2E tests with Postman/Newman
- Manual test cases via Makefile targets

### 5. Documentation
- Swagger for API documentation
- Auto-generated from code annotations
- Available at `/swagger/index.html`

## Important Constraints

### Input Validation
- Flight segments must be non-empty
- Each segment must have exactly 2 airports (source, destination)
- Airport codes should be 3-letter uppercase (convention)
- Flights must form a connected path (no disconnected segments)

### Error Handling
- 400 Bad Request: Invalid input format or validation failure
- 500 Internal Server Error: Algorithm or processing error
- Descriptive error messages in JSON response

## Performance Considerations

### Benchmarking
- Baseline benchmarks saved in `benchmarks/` directory
- Use `make bench-save` before optimization
- Use `make bench-compare` to verify improvements
- Track performance for large inputs (100+ segments)

### Optimization Priorities
1. Algorithm complexity (O(n) vs O(n²))
2. Data structure selection (map vs slice)
3. Memory allocations
4. Avoid premature optimization

## Dependencies

### Core
- `github.com/labstack/echo/v5` - Web framework
- `github.com/swaggo/echo-swagger` - Swagger UI
- `github.com/swaggo/swag` - Swagger generator
- `github.com/joho/godotenv` - Environment variables

### Development Tools
- `golangci-lint` - Comprehensive linter
- `gosec` - Security scanner
- `gocritic` - Code critic
- `benchstat` - Benchmark comparison
- `newman` - API testing (Postman CLI)

## Common Workflows

### Adding a New Endpoint
1. Add Swagger annotations to handler
2. Implement handler in `internal/handlers/`
3. Register route in `internal/routes/`
4. Run `make api-docs` to update Swagger
5. Add tests
6. Add Postman/Newman test case

### Performance Optimization
1. Identify bottleneck (profiling or benchmarks)
2. Save baseline: `make bench-save`
3. Implement optimization
4. Save new benchmark: `make bench-save`
5. Compare: `make bench-compare`
6. Verify tests still pass: `make test`

### Before Committing
```bash
make lint          # Check code quality
make critic        # Additional code review
make sec           # Security scan
make test          # Run tests
make api-docs      # Update Swagger docs
make build         # Ensure it compiles
make e2e           # E2E tests (if server running)
```

## Known Issues / Technical Debt

_(Document any known issues or areas for improvement here)_

## Future Enhancements

_(Document planned features or improvements here)_

Examples:
- [ ] Add support for multi-leg journeys with layovers
- [ ] Add caching for frequently requested paths
- [ ] Add metrics/monitoring endpoints
- [ ] Add authentication/authorization
- [ ] Support for more complex graph algorithms
- [ ] Database persistence for flight data

## Environment Variables

Currently loaded from `.env` file:
```bash
# Add variables as project grows
# PORT=8080
# LOG_LEVEL=info
```

## CI/CD Pipeline

### GitHub Actions Workflow
1. Checkout code
2. Setup Node.js (for Newman)
3. Setup Go 1.26.0
4. Install dependencies (`make deps`)
5. Install Newman
6. Run tests (`make test`)
7. Build binary (`make build`)
8. Start server
9. Wait for server ready
10. Run E2E tests (`make e2e`)

### Status Badges
- CI status
- License
- Renovate (dependency updates)
- Hit counter

## Versioning

- Version stored in `pkg/api/version.txt`
- Semantic versioning: MAJOR.MINOR.PATCH
- Use `make release` to create and push tags
- Tags trigger release workflow

## Contact / Ownership

**Repository**: https://github.com/AndriyKalashnykov/flight-path
**Owner**: Andriy Kalashnykov
**License**: MIT
