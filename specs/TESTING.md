# Testing Specification

## 1. Unit Tests — Algorithm

**Location**: `internal/handlers/api_test.go`

| Test | Input | Expected |
|---|---|---|
| empty input | `[]` | `("", "")` |
| single flight | `[SFO->EWR]` | `("SFO", "EWR")` |
| two flights in order | `[SFO->ATL, ATL->EWR]` | `("SFO", "EWR")` |
| two flights reversed | `[ATL->EWR, SFO->ATL]` | `("SFO", "EWR")` |
| four flights shuffled | 4-segment path | `("SFO", "EWR")` |
| TestFlights fixture | 19 segments | `("BGY", "AKL")` |

## 2. Unit Tests — Handlers

**Location**: `internal/handlers/flight_test.go`

| Test | Input | Expected Status |
|---|---|---|
| single segment | `[["SFO", "EWR"]]` | 200 |
| two segments | `[["ATL", "EWR"], ["SFO", "ATL"]]` | 200 |
| four segments | 4-segment path | 200 |
| empty array | `[]` | 400 |
| incomplete segment | `[["SFO"]]` | 400 |
| malformed JSON | `not json` | 500 |
| empty body | `` | 400 |

**Location**: `internal/handlers/healthcheck_test.go`

| Test | Expected |
|---|---|
| GET / | 200, `{"data": "Server is up and running"}` |

## 3. Benchmark Tests

**Location**: `internal/handlers/api_bench_test.go`

| Benchmark | Dataset |
|---|---|
| `BenchmarkFindItinerary_10` | 10 flights |
| `BenchmarkFindItinerary_50` | 50 flights |
| `BenchmarkFindItinerary_100` | 100 flights |
| `BenchmarkFindItinerary_500` | 500 flights |

Benchmarks test production `FindItinerary` directly (O(n) algorithm).

```bash
make bench          # Run benchmarks (3s each)
make bench-save     # Save to benchmarks/bench_YYYYMMDD_HHMMSS.txt
make bench-compare  # Compare latest two with benchstat
```

## 4. E2E Tests (Postman/Newman)

**Location**: `test/FlightPath.postman_collection.json`
**Prerequisite**: Server running on `localhost:8080`

### Validation Strategy

Hybrid approach — Ajv JSON Schema validation for response structure, Chai assertions for exact values:

- **Collection pre-request**: Defines two global JSON schemas (`successSchema`, `errorSchema`) stored via `pm.globals`
- **Collection test**: Ajv validates every response against the appropriate schema (auto-selected by status code)
- **Request tests**: Status code check + business value assertions

#### Global Schemas

| Schema | Type | Constraints |
|---|---|---|
| `successSchema` | `array` | Exactly 2 items, each a 3-letter uppercase string (`^[A-Z]{3}$`) |
| `errorSchema` | `object` | Required `Error` (string, minLength 1), optional `Index` (integer), no additional properties |

### Happy Path Cases

| Test | Input | Expected |
|---|---|---|
| UseCase01 | `[["SFO", "EWR"]]` | `["SFO", "EWR"]` |
| UseCase02 | `[["ATL", "EWR"], ["SFO", "ATL"]]` | `["SFO", "EWR"]` |
| UseCase03 | 4-segment path | `["SFO", "EWR"]` |

### Negative Cases

| Test | Input | Expected Status | Error Contains |
|---|---|---|---|
| UseCase04_EmptyBody | `[]` | 400 | "empty" |
| UseCase05_MalformedJSON | `not valid json` | 400 | "parse" |
| UseCase06_IncompleteSegment | `[["SFO"]]` | 400 | "source and destination" |

```bash
make e2e    # newman run ./test/FlightPath.postman_collection.json
```

## 5. Manual curl Tests

```bash
make test-case-one      # [["SFO", "EWR"]]
make test-case-two      # [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three    # 4-segment path
```

## Test Data

**Static fixture**: `pkg/api/data.go` -- `TestFlights` (19 segments, BGY -> AKL). Used by `TestFindItinerary`.
**Synthetic**: `generateFlights(n)` in bench test -- creates chain using sequential runes.

## Running All Tests

```bash
make test   # go generate && go test -v ./...
```
