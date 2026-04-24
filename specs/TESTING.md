# Testing Specification

Three test layers, from fastest to most realistic. All three run in CI and in `make ci` / `make check`.

## Layer 1 — Unit & Handler Tests (`make test`)

`go test -race -v ./...`. Runs in seconds.

### Algorithm — `internal/handlers/api_test.go`

| Test | Input | Expected |
|---|---|---|
| empty input | `[]` | `("", "")` |
| single flight | `[SFO->EWR]` | `("SFO", "EWR")` |
| two flights in order | `[SFO->ATL, ATL->EWR]` | `("SFO", "EWR")` |
| two flights reversed | `[ATL->EWR, SFO->ATL]` | `("SFO", "EWR")` |
| four flights shuffled | 4-segment path | `("SFO", "EWR")` |
| TestFlights fixture | 19 segments, shuffled | `("BGY", "AKL")` |

### Handler — `internal/handlers/flight_test.go`

| Test | Input | Expected Status |
|---|---|---|
| single segment | `[["SFO", "EWR"]]` | 200 |
| two segments | `[["ATL", "EWR"], ["SFO", "ATL"]]` | 200 |
| four segments | 4-segment path | 200 |
| empty array | `[]` | 400 |
| incomplete segment | `[["SFO"]]` | 400 |
| malformed JSON | `not json` | 400 |
| empty body | `` | 400 |

### Health — `internal/handlers/healthcheck_test.go`

| Test | Expected |
|---|---|
| GET / | 200, `{"data": "Server is up and running"}` |

### Coverage gate

`make coverage-check` fails the build when total coverage drops below 80%.

## Layer 2 — Integration Tests (`make integration-test`)

`go test -race -tags=integration -v ./internal/app/...`. Runs in tens of seconds.

**Location**: `internal/app/app_integration_test.go` (build tag `//go:build integration`).

Exercises the full `app.New()` bootstrap — middleware chain, CORS branches, security headers, error envelope, preflight `OPTIONS`, panic recovery — via `httptest`. Covers the surface area Layer 1 intentionally skips (middleware, route registration, `HTTPErrorHandler`).

## Layer 3 — End-to-End Tests (`make e2e` / `make e2e-quick`)

`make e2e` is self-contained: it builds the binary, starts the server on `SERVER_PORT`, runs the Newman collection against `localhost`, then tears the server down. `make e2e-quick` skips the build/start/stop steps and runs Newman against an already-running server.

**Location**: `test/FlightPath.postman_collection.json` — 18 test cases.

### Validation strategy

Hybrid — [Ajv](https://ajv.js.org/) JSON Schema validation for response structure plus [Chai](https://www.chaijs.com/) assertions for exact business values:

- **Collection pre-request**: defines two global schemas (`successSchema`, `errorSchema`) stored via `pm.globals`
- **Collection test**: Ajv validates every `/calculate` response against the appropriate schema (selected by status code). Non-`/calculate` requests (HealthCheck, Swagger_UI) skip the collection-level schema check so their request-level tests run in isolation
- **Request tests**: status code + business value assertions (start/end airports, header presence, error message substring)

### Global schemas

| Schema | Type | Constraints |
|---|---|---|
| `successSchema` | `array` | Exactly 2 items, each a 3-letter uppercase string (`^[A-Z]{3}$`) |
| `errorSchema` | `object` | Required `Error` (string, minLength 1), optional `Index` (integer), no additional properties |

### Cases

| Test | Input / Scope | Expected |
|---|---|---|
| HealthCheck | `GET /` | 200, `{"data": ...}` |
| UseCase01 | `[["SFO","EWR"]]` | 200, `["SFO","EWR"]` |
| UseCase02 | `[["ATL","EWR"],["SFO","ATL"]]` | 200, `["SFO","EWR"]` |
| UseCase03 | 4-segment path | 200, `["SFO","EWR"]` |
| UseCase04_EmptyBody | `[]` | 400, error contains "empty" |
| UseCase05_MalformedJSON | `not valid json` | 400, error contains "parse" |
| UseCase06_IncompleteSegment | `[["SFO"]]` | 400, error contains "source and destination" |
| UseCase07_ExtraItemsInSegmentIgnored | `[["SFO","EWR","JFK"]]` | 200, first two elements used |
| UseCase08_TenSegmentChain | 10 scrambled segments | 200, resolves LAX→SFO |
| UseCase09_ObjectRoot | `{"foo":"bar"}` | 400, error contains "parse" |
| UseCase10_SecondSegmentIncomplete | `[["SFO","EWR"],["JFK"]]` | 400 with `Index: 1` |
| HealthCheck_SecurityHeaders | `GET /` | asserts `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` |
| HealthCheck_CORS | `OPTIONS /` | default `Access-Control-Allow-Origin: *` |
| Swagger_UI | `GET /swagger/index.html` | 200, HTML |
| UseCase11_WrongMethod | `GET /calculate` | 405 |
| UseCase12_UnknownRoute | `GET /does-not-exist` | 404 |
| UseCase13_LargeChain | 100-segment chain | 200 |
| UseCase14_WrongContentType | `text/plain` body | 400, error contains "content-type" |

## Layer 4 — Benchmarks

`internal/handlers/api_bench_test.go`:

| Benchmark | Dataset |
|---|---|
| `BenchmarkFindItinerary_10` | 10 flights |
| `BenchmarkFindItinerary_50` | 50 flights |
| `BenchmarkFindItinerary_100` | 100 flights |
| `BenchmarkFindItinerary_500` | 500 flights |

```bash
make bench          # run benchmarks
make bench-save     # save to benchmarks/bench_YYYYMMDD_HHMMSS.txt
make bench-compare  # auto-discover latest two files and diff with benchstat
```

## Layer 5 — Fuzz

`internal/handlers/api_fuzz_test.go` — run for 30 s via `make fuzz` (`go test -fuzz=. -fuzztime=30s`).

## Manual curl Tests

```bash
make test-case-one      # [["SFO", "EWR"]]
make test-case-two      # [["ATL", "EWR"], ["SFO", "ATL"]]
make test-case-three    # 4-segment path
```

These are optional convenience targets for hand-checking a running server; they are not part of CI.

## Test Data

- **Static fixture**: `pkg/api/data.go` → `TestFlights` (19 segments, BGY → AKL, stored shuffled)
- **Synthetic**: `generateFlights(n)` in the benchmark test — creates a chain using sequential runes
