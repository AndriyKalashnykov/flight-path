Run benchmarks and optionally compare against the previous run:

1. Save current benchmark results: `make bench-save`
2. Display the benchmark results (ops/sec, memory allocations, bytes per op)
3. Check if a previous benchmark file exists in `benchmarks/`
4. If a previous run exists, compare with: `make bench-compare`
5. Summarize findings — highlight any regressions or improvements

Present results in a clear table format with metric names, values, and deltas if comparing.
