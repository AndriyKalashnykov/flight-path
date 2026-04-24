# Data Models Specification

## Core Types

### Flight (`pkg/api/data.go`)

```go
type Flight struct {
    Start string  // Source airport code
    End   string  // Destination airport code
}
```

## Wire Formats

### POST /calculate Request

```json
[["SFO", "ATL"], ["ATL", "EWR"]]
```
Go type: `[][]string`

### POST /calculate Success Response (200)

```json
["SFO", "EWR"]
```
Go type: `[]string` -- index 0 = start, index 1 = end

### Error Responses (400)

```json
{"Error": "descriptive message"}
```
Segment errors include index: `{"Error": "...", "Index": 2}`

Go type: `map[string]any`. Note the capital-E `"Error"` key — this is the current contract enforced by Postman Ajv `errorSchema` validation.

A `500` status code is reserved for unexpected server errors (e.g., panics caught by `middleware.Recover`); it is not emitted by normal validation failures.

### GET / Health Response (200)

```json
{"data": "Server is up and running"}
```

## Internal Transformation

```
[][]string → []api.Flight → FindItinerary() → (start, end) → []string
```

## Validation (implemented)

| Rule | Status | Error |
|---|---|---|
| Parseable JSON | 400 | "Can't parse the payload" |
| Non-empty array | 400 | "Flight segments cannot be empty" |
| Segment >= 2 elements | 400 | "Each flight segment must contain both source and destination" (includes `Index`) |

## Validation (not implemented)

- 3-letter uppercase IATA codes
- Source != destination within segment
- Connected path (no disconnected subgraphs)
- No duplicate airports
- Extra elements in segment (>2) silently ignored

## Test Fixtures

### TestFlights (`pkg/api/data.go`)

19-segment chain: `BGY → RAR → AUH → FCO → BCN → PSC → BLQ → MAD → SFO → ATL → GSO → IND → EWR → CHI → JFK → AAL → HEL → CAK → BJZ → AKL`.

Start: BGY, End: AKL. Stored in the source in shuffled order to exercise the algorithm's unordered-input behavior.
