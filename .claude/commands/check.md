Run the full pre-commit checklist for this project. Execute each step sequentially and report results:

1. `make lint` — Code quality (golangci-lint)
2. `make critic` — Code review (go-critic)
3. `make sec` — Security scan (gosec)
4. `make test` — Unit tests
5. `make api-docs` — Regenerate Swagger docs
6. `make build` — Compile binary

After all steps, provide a summary table showing pass/fail status for each check. If any step fails, show the relevant error output and suggest a fix.
