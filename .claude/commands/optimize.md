Run the performance optimization workflow:

1. Save the current benchmark baseline: `make bench-save`
2. Show the current benchmark results
3. Ask what to optimize (or analyze the code to suggest optimizations)
4. After I approve changes, implement the optimization
5. Save new benchmark results: `make bench-save`
6. Compare before/after: `make bench-compare`
7. Run `make test` to verify correctness is preserved
8. Summarize the performance improvement with before/after numbers
