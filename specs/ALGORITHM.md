# Algorithm Specification

## Problem

Given an unordered list of flight segments forming a single connected path, find the starting airport (no incoming flights) and the ending airport (no outgoing flights).

## Production Implementation: `FindItinerary`

**Location**: `internal/handlers/api.go`

### Approach

Concurrent processing with `sync.Map` for thread-safe lookups.

### Steps

1. For each flight `v`, spawn a goroutine that iterates all flights `w`:
   - If `v.Start == w.End` → mark `v.Start` as "has incoming" in map `s`
   - If `v.End == w.Start` → mark `v.End` as "has outgoing" in map `e`
2. Wait for all goroutines (`sync.WaitGroup`)
3. Scan flights:
   - **Start**: first `v.Start` not in `s` (no incoming edge)
   - **End**: first `v.End` not in `e` (no outgoing edge)

### Signature

```go
func FindItinerary(flights []api.Flight, s, e *sync.Map) (start, end string)
```

### Complexity

| Metric | Value |
|---|---|
| Time | O(n^2) -- each goroutine iterates all flights |
| Space | O(n) -- sync.Map entries |
| Concurrency | n goroutines (one per flight) |

## Optimized Implementation: `FindItineraryOptimized`

**Location**: `internal/handlers/api_bench_test.go` (benchmark-only, not in production)

### Approach

Two-pass O(n) using plain maps.

### Steps

1. Build `starts` and `ends` sets in one pass
2. Scan again: `f.Start` not in `ends` = start; `f.End` not in `starts` = end

### Complexity

| Metric | Value |
|---|---|
| Time | O(n) -- two linear passes |
| Space | O(n) -- two hash maps |

## Correctness Invariants

- Segments must form a single linear path (in-degree and out-degree <= 1)
- Exactly one airport has in-degree 0 (start) and one has out-degree 0 (end)
- Algorithm returns only endpoints, NOT the full ordered itinerary
