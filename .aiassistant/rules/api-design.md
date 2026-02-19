---
apply: always
---

# API Design Guidelines

## REST API Principles

### RESTful Conventions
- Use appropriate HTTP methods (GET, POST, PUT, DELETE)
- Use meaningful resource names in URLs
- Return appropriate HTTP status codes
- Use JSON for request/response bodies
- Follow consistent URL naming patterns

### Status Codes
Use appropriate status codes consistently:

**Success Codes:**
- `200 OK` - Successful request
- `201 Created` - Resource successfully created
- `204 No Content` - Successful request with no response body

**Client Error Codes:**
- `400 Bad Request` - Invalid input, validation errors
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Authenticated but not authorized
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Valid JSON but business logic error

**Server Error Codes:**
- `500 Internal Server Error` - Unexpected server error
- `503 Service Unavailable` - Temporary service issue

## Request/Response Format

### Request Structure
```json
// POST /calculate
Content-Type: application/json

[["SFO", "EWR"], ["ATL", "SFO"]]
```

**Best Practices:**
- Accept JSON in request body
- Validate content-type header
- Use arrays/objects for complex data
- Keep request format simple and intuitive

### Response Structure

**Success Response:**
```json
// 200 OK
["SFO", "EWR"]
```

**Error Response:**
```json
// 400 Bad Request
{
  "error": "flight segments cannot be empty"
}

// 500 Internal Server Error
{
  "error": "failed to calculate flight path"
}
```

**Best Practices:**
- Use consistent error format across all endpoints
- Include descriptive error messages
- Don't expose internal error details to clients
- Log detailed errors server-side

## Swagger Documentation

### Endpoint Documentation
Every public endpoint must have complete Swagger documentation:

```go
// CalculateFlightPath godoc
// @Summary Calculate flight path from segments
// @Description Determines the complete flight path (start and end airports) from a list of unordered flight segments
// @Tags Flight
// @ID calculate-flight-path
// @Accept json
// @Produce json
// @Param flightSegments body [][]string true "Array of flight segments, each segment is [source, destination]"
// @Success 200 {array} string "Array containing [start_airport, end_airport]"
// @Failure 400 {object} map[string]interface{} "Invalid input or validation error"
// @Failure 500 {object} map[string]interface{} "Internal server error"
// @Router /calculate [post]
func CalculateFlightPath(c echo.Context) error {
    // Implementation
}
```

### Documentation Requirements
- **@Summary**: Brief one-line description
- **@Description**: Detailed explanation of what the endpoint does
- **@Tags**: Logical grouping (e.g., Flight, Health, Admin)
- **@ID**: Unique operation ID (kebab-case)
- **@Accept**: Request content types (usually `json`)
- **@Produce**: Response content types (usually `json`)
- **@Param**: Document each parameter with name, type, location, required flag, and description
- **@Success**: Document successful responses with status code and type
- **@Failure**: Document all possible error responses
- **@Router**: Endpoint path and HTTP method

### Parameter Documentation
```go
// Path parameter
// @Param id path string true "User ID"

// Query parameter
// @Param limit query int false "Result limit" default(10)

// Body parameter
// @Param user body User true "User object"

// Header parameter
// @Param Authorization header string true "Bearer token"
```

### Response Type Documentation
```go
// Simple type
// @Success 200 {string} string "Success message"

// Array
// @Success 200 {array} string "List of airport codes"

// Object
// @Success 200 {object} FlightPath "Flight path result"

// Map/any
// @Success 200 {object} map[string]interface{} "Dynamic response"
```

## Input Validation

### Validation Strategy
1. **Syntax validation**: Check JSON format (handled by framework)
2. **Schema validation**: Check data types and structure
3. **Business validation**: Check business rules and constraints
4. **Return early**: Validate and fail fast before processing

### Example Validation Flow
```go
func FlightHandler(c echo.Context) error {
    // 1. Bind and syntax validation
    var segments [][]string
    if err := c.Bind(&segments); err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{
            "error": "invalid JSON format",
        })
    }

    // 2. Schema validation
    if err := ValidateFlightSegments(segments); err != nil {
        return c.JSON(http.StatusBadRequest, map[string]string{
            "error": err.Error(),
        })
    }

    // 3. Business logic
    result, err := CalculateFlightPath(segments)
    if err != nil {
        // Business logic error (e.g., disconnected flights)
        return c.JSON(http.StatusUnprocessableEntity, map[string]string{
            "error": err.Error(),
        })
    }

    // 4. Success response
    return c.JSON(http.StatusOK, result)
}
```

### Validation Rules
```go
func ValidateFlightSegments(segments [][]string) error {
    if len(segments) == 0 {
        return errors.New("flight segments cannot be empty")
    }

    for i, segment := range segments {
        if len(segment) != 2 {
            return fmt.Errorf("segment %d: must contain exactly 2 airports", i)
        }

        if !isValidAirportCode(segment[0]) {
            return fmt.Errorf("segment %d: invalid source airport code '%s'", i, segment[0])
        }

        if !isValidAirportCode(segment[1]) {
            return fmt.Errorf("segment %d: invalid destination airport code '%s'", i, segment[1])
        }

        if segment[0] == segment[1] {
            return fmt.Errorf("segment %d: source and destination cannot be the same", i)
        }
    }

    return nil
}

func isValidAirportCode(code string) bool {
    // Airport codes are typically 3 uppercase letters
    return len(code) == 3 && code == strings.ToUpper(code)
}
```

## Error Handling

### Error Response Format
Use consistent error response structure:

```go
type ErrorResponse struct {
    Error   string `json:"error"`           // User-friendly message
    Code    string `json:"code,omitempty"`  // Optional error code
    Details string `json:"details,omitempty"` // Optional additional details
}
```

### Error Handling Pattern
```go
func Handler(c echo.Context) error {
    result, err := ProcessRequest(input)
    if err != nil {
        // Log detailed error for debugging
        log.Printf("ERROR: %v", err)

        // Return user-friendly error
        return c.JSON(
            http.StatusInternalServerError,
            map[string]string{"error": "failed to process request"},
        )
    }

    return c.JSON(http.StatusOK, result)
}
```

### Error Categories
**Validation Errors (400):**
```go
return c.JSON(http.StatusBadRequest, map[string]string{
    "error": "validation failed: airport code must be 3 letters",
})
```

**Business Logic Errors (422):**
```go
return c.JSON(http.StatusUnprocessableEntity, map[string]string{
    "error": "disconnected flight segments: no valid path found",
})
```

**Internal Errors (500):**
```go
log.Printf("ERROR: unexpected error: %v", err)
return c.JSON(http.StatusInternalServerError, map[string]string{
    "error": "internal server error",
})
```

## API Versioning

### URL Versioning (when needed)
If versioning becomes necessary:
```
/v1/calculate
/v2/calculate
```

### Current Approach
- No versioning initially (single version)
- Version info available via healthcheck or version endpoint
- Consider versioning when breaking changes are needed

## Content Negotiation

### Content-Type Headers
**Request:**
```
Content-Type: application/json
```

**Response:**
```
Content-Type: application/json; charset=utf-8
```

### Handle Missing Content-Type
```go
if c.Request().Header.Get("Content-Type") != "application/json" {
    return c.JSON(http.StatusBadRequest, map[string]string{
        "error": "Content-Type must be application/json",
    })
}
```

## CORS Configuration

### CORS Setup (Echo v5)
```go
e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
    AllowOrigins: []string{"http://localhost:3000", "https://yourdomain.com"},
    AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodDelete},
    AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept},
}))
```

## Health Checks

### Health Check Endpoint
```go
// HealthCheck godoc
// @Summary Health check endpoint
// @Description Returns server health status
// @Tags Health
// @ID health-check
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func HealthCheck(c echo.Context) error {
    return c.JSON(http.StatusOK, map[string]string{
        "status": "ok",
        "version": version,
    })
}
```

### Readiness vs Liveness
- **Liveness** (`/health`): Is the server running?
- **Readiness** (`/ready`): Is the server ready to accept traffic? (Check dependencies)

## Rate Limiting

### When to Add Rate Limiting
- High-traffic production APIs
- Public APIs without authentication
- Preventing abuse or DoS attacks

### Echo Middleware Example
```go
e.Use(middleware.RateLimiter(middleware.NewRateLimiterMemoryStore(20)))
```

## API Documentation Best Practices

### Keep Swagger Docs Updated
- Run `make api-docs` after every API change
- Review generated Swagger JSON for accuracy
- Test API via Swagger UI before committing

### Provide Examples
Include request/response examples in Swagger:
```go
// @Example request
// [["SFO", "ATL"], ["ATL", "EWR"]]
//
// @Example response
// ["SFO", "EWR"]
```

### Document Edge Cases
Document important behaviors:
- Empty input behavior
- Validation rules
- Error scenarios
- Performance characteristics (for large inputs)

## Testing API Design

### Test All Endpoints
```bash
make test-case-one      # Simple case
make test-case-two      # Multiple segments
make test-case-three    # Complex path
make e2e                # Full E2E suite
```

### Manual Testing Checklist
- [ ] Valid input returns 200 with correct result
- [ ] Empty input returns 400 with error message
- [ ] Invalid JSON returns 400
- [ ] Disconnected flights return appropriate error
- [ ] Missing Content-Type handled gracefully
- [ ] Large input performs acceptably
- [ ] Swagger UI displays correctly
- [ ] Error messages are user-friendly

## API Security

### Input Sanitization
- Validate all input before processing
- Limit input size to prevent DoS
- Sanitize strings to prevent injection

### Security Headers
```go
e.Use(middleware.Secure())
```

### Run Security Checks
```bash
make sec  # Run gosec security scanner
```

### Security Best Practices
- Don't expose internal error details
- Log security events
- Validate all user input
- Use HTTPS in production
- Consider authentication for sensitive endpoints
