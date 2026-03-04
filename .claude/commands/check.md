Run the full pre-commit checklist for this project. Execute each step sequentially and report results:

1. `make lint` — Code quality (golangci-lint, 60+ linters)
2. `make sec` — Security scan (gosec)
3. `make vulncheck` — Dependency vulnerability check (govulncheck)
4. `make secrets` — Secrets detection (gitleaks)
5. `make lint-ci` — GitHub Actions lint (actionlint)
6. `make test` — Unit tests
7. `make api-docs` — Regenerate Swagger docs
8. `make build` — Compile binary

After all steps, provide a summary table showing pass/fail status for each check. If any step fails, show the relevant error output and suggest a fix.
