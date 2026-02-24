# Testing Specification

## 1. Benchmark Tests

**Location**: `internal/handlers/api_bench_test.go`

| Benchmark | Dataset |
|---|---|
| `BenchmarkFindItinerary_10` | 10 flights |
| `BenchmarkFindItinerary_50` | 50 flights |
| `BenchmarkFindItinerary_100` | 100 flights |
| `BenchmarkFindItinerary_500` | 500 flights |

Synthetic data: `generateFlights(n)` creates chain `A->B->C->...`

```bash
make bench          # Run benchmarks (3s each)
make bench-save     # Save to benchmarks/bench_YYYYMMDD_HHMMSS.txt
make bench-compare  # Compare latest two with benchstat
```

## 2. E2E Tests (Postman/Newman)

**Location**: `test/FlightPath.postman_collection.json`
**Prerequisite**: Server running on `localhost:8080`

| Test | Input | Expected |
|---|---|---|
| UseCase01 | `[["SFO", "EWR"]]` | `["SFO", "EWR"]` |
| UseCase02 | `[["ATL", "EWR"], ["SFO", "ATL"]]` | `["SFO", "EWR"]` |
| UseCase03 | `[["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]` | `["SFO", "EWR"]` |

Assertions per case: status 200, valid JSON body, correct start/end values.

```bash
make e2e    # newman run ./test/FlightPath.postman_collection.json
```

## 3. Manual curl Tests

```bash
make test-case-one      # [["SFO", "EWR"]]
make test-case-two      # [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three    # 4-segment path
```

## 4. Unit Tests

```bash
make test   # go generate && go test -v
```

## Test Data

**Static fixture**: `pkg/api/data.go` -- `TestFlights` (19 segments, BGY -> AKL)
**Synthetic**: `generateFlights(n)` in bench test

## Coverage Gaps

- No unit tests for production `FindItinerary`
- No handler tests (`FlightCalculate`, `ServerHealthCheck`)
- No negative E2E cases (empty body, malformed JSON, invalid segments)
- No validation logic tests
- `TestFlights` fixture unused by any test
