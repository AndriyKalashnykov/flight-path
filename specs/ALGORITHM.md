# Algorithm Specification

## Problem

Given an unordered list of flight segments forming a single connected path, find the starting airport (no incoming flights) and the ending airport (no outgoing flights).

## Production Implementation: `FindItinerary`

**Location**: `internal/handlers/api.go`

### Approach

Two-pass O(n) algorithm using plain maps.

### Steps

1. Build two sets in one pass:
   - `starts`: all source airports
   - `ends`: all destination airports
2. Scan flights again:
   - **Start airport**: `f.Start` not in `ends` (no flight arrives here)
   - **End airport**: `f.End` not in `starts` (no flight departs from here)

### Signature

```go
func FindItinerary(flights []api.Flight) (start, end string)
```

### Complexity

| Metric | Value |
|---|---|
| Time | O(n) -- two linear passes |
| Space | O(n) -- two hash maps |
| Concurrency | None (single-threaded, no overhead) |

## Correctness Invariants

- Segments must form a single linear path (in-degree and out-degree <= 1)
- Exactly one airport has in-degree 0 (start) and one has out-degree 0 (end)
- If a single segment is provided, `start = source` and `end = destination`
- Empty input returns `("", "")` -- guarded by handler validation
- Algorithm returns only endpoints, NOT the full ordered itinerary

## Historical Note

Previously used an O(n^2) implementation with goroutines and `sync.Map`. Replaced 2026-02-24 with the O(n) version that was already proven in benchmarks.
