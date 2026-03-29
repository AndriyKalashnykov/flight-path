# Implementation Plan: SAST, DAST, Linting & Security Tooling

Based on analysis in [SECURITY-TOOLS-ANALYSIS.md](./SECURITY-TOOLS-ANALYSIS.md).

---

## Phase 1 — Linting Configuration (`.golangci.yml`)

**Status**: DONE

**What**: Created `.golangci.yml` with `default: all` and a curated disable list. Enables 60+ linters beyond the previous defaults-only run.

**Key linters now active** (were previously off):
- `bodyclose` — unclosed HTTP response bodies
- `gosec` — security patterns (was CLI-only, now integrated)
- `gocritic` — diagnostic/style/performance/opinionated checks (replaces standalone `make critic`)
- `revive` — drop-in golint replacement
- `errcheck` — with type assertions and blank checks enabled
- `staticcheck`, `unused`, `ineffassign` — already default, now configured
- `exhaustive` — enum switch completeness
- `dupl` — duplicate code detection
- `misspell` — typo detection
- `unconvert` — unnecessary type conversions
- `unparam` — unused function parameters
- `nestif` — deeply nested if detection
- `cyclop` / `gocyclo` — cyclomatic complexity
- `prealloc` — slice pre-allocation hints
- `nilerr` — nil error with non-nil value returns
- `errorlint` — Go 1.13+ error wrapping patterns
- `bodyclose` — HTTP response body leak detection
- `noctx` — missing context.Context in HTTP calls
- `modernize` — modern Go idiom suggestions

**Import formatting** (`goimports`):
- Local prefix `github.com/AndriyKalashnykov/flight-path` separates project imports from third-party
- 3 files need auto-fix: `main.go`, `internal/routes/flight.go`, `internal/routes/healthcheck.go`
- Fix: `golangci-lint run --fix ./...`

**Changes required**:
| File | Change |
|------|--------|
| `.golangci.yml` | Created (new file) |
| `main.go` | Import grouping (auto-fix) |
| `internal/handlers/flight.go` | Import grouping (auto-fix) |
| `internal/routes/flight.go` | Import grouping (auto-fix) |
| `internal/routes/healthcheck.go` | Import grouping (auto-fix) |

---

## Phase 2 — Dependency Vulnerability Scanning

**Tools**: `govulncheck`

**What**: Official Go tool that checks `go.mod` dependencies against the Go vulnerability database. Zero false positives — only reports vulnerabilities in code paths actually called.

**Changes required**:

### 2.1 — Makefile: `deps` target

Add `govulncheck` installation alongside existing tools:

```makefile
deps:
	@command -v swag >/dev/null 2>&1 || { echo "Installing swag..."; go install github.com/swaggo/swag/cmd/swag@latest; }
	@command -v gosec >/dev/null 2>&1 || { echo "Installing gosec..."; go install github.com/securego/gosec/v2/cmd/gosec@latest; }
	@command -v benchstat >/dev/null 2>&1 || { echo "Installing benchstat..."; go install golang.org/x/perf/cmd/benchstat@latest; }
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint..."; curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $$(go env GOPATH)/bin; }
	@command -v govulncheck >/dev/null 2>&1 || { echo "Installing govulncheck..."; go install golang.org/x/vuln/cmd/govulncheck@latest; }
	@command -v gitleaks >/dev/null 2>&1 || { echo "Installing gitleaks..."; go install github.com/zricethezav/gitleaks/v8/cmd/gitleaks@latest; }
	@command -v actionlint >/dev/null 2>&1 || { echo "Installing actionlint..."; go install github.com/rhysd/actionlint/cmd/actionlint@latest; }
	@command -v node >/dev/null 2>&1 || { echo "Installing Node.js LTS via nvm..."; . "$${NVM_DIR:-$$HOME/.nvm}/nvm.sh" && nvm install --lts && nvm use --lts; }
	@command -v newman >/dev/null 2>&1 || { echo "Installing newman..."; npm install --location=global newman; }
```

### 2.2 — Makefile: new `vulncheck` target

```makefile
#vulncheck: @ Run Go vulnerability check on dependencies
vulncheck: deps
	govulncheck ./...
```

### 2.3 — Makefile: update `build` target

Add `vulncheck` to the build pipeline:

```makefile
build: deps lint critic sec vulncheck api-docs
```

### 2.4 — CI: add to `static-check` job

```yaml
      - name: staticcheck
        run: |
          export PATH=$PATH:/home/runner/go/bin
          make deps lint critic sec vulncheck
```

---

## Phase 3 — Secrets Detection

**Tools**: `gitleaks`

**What**: Scans git history and working tree for hardcoded secrets (API keys, passwords, tokens). Prevents accidental credential leaks.

**Changes required**:

### 3.1 — Makefile: new `secrets` target

```makefile
#secrets: @ Scan for hardcoded secrets in source code and git history
secrets: deps
	gitleaks detect --source . --verbose
```

### 3.2 — Makefile: update `build` target

```makefile
build: deps lint critic sec vulncheck secrets api-docs
```

### 3.3 — CI: add to `static-check` job

```yaml
      - name: staticcheck
        run: |
          export PATH=$PATH:/home/runner/go/bin
          make deps lint critic sec vulncheck secrets
```

---

## Phase 4 — GitHub Actions Linting

**Tools**: `actionlint`

**What**: Lints `.github/workflows/*.yml` files for common misconfigurations (invalid expressions, unknown actions, type errors).

**Changes required**:

### 4.1 — Makefile: new `lint-ci` target

```makefile
#lint-ci: @ Lint GitHub Actions workflow files
lint-ci: deps
	actionlint
```

### 4.2 — CI: add to `static-check` job

```yaml
      - name: staticcheck
        run: |
          export PATH=$PATH:/home/runner/go/bin
          make deps lint critic sec vulncheck secrets lint-ci
```

---

## Phase 5 — Fuzz Testing

**Tools**: Go native fuzzing (built-in, no install needed)

**What**: Fuzz-tests `FindItinerary` with random inputs to find panics, crashes, and edge cases the existing table-driven tests don't cover.

**Changes required**:

### 5.1 — New file: `internal/handlers/api_fuzz_test.go`

```go
package handlers

import (
	"testing"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

func FuzzFindItinerary(f *testing.F) {
	// Seed corpus from existing test cases.
	f.Add("SFO", "EWR", "EWR", "ATL")
	f.Add("ATL", "EWR", "SFO", "ATL")
	f.Add("IND", "EWR", "SFO", "ATL")
	f.Add("", "", "", "")

	f.Fuzz(func(t *testing.T, s1, d1, s2, d2 string) {
		flights := []api.Flight{
			{Start: s1, End: d1},
			{Start: s2, End: d2},
		}
		// FindItinerary must never panic regardless of input.
		FindItinerary(flights)
	})
}
```

### 5.2 — Makefile: new `fuzz` target

```makefile
#fuzz: @ Run fuzz tests for 30 seconds
fuzz:
	go test ./internal/handlers/ -fuzz=FuzzFindItinerary -fuzztime=30s
```

---

## Phase 6 — DAST (Dynamic Application Security Testing)

**Tools**: OWASP ZAP (via GitHub Action, uses existing Swagger spec)

**What**: Automated API security scan against the running server, importing the OpenAPI/Swagger spec to discover and test all endpoints for injection, auth bypass, information disclosure, etc.

**Changes required**:

### 6.1 — CI: new `dast` job in `.github/workflows/ci.yml`

```yaml
  dast:
    needs: [integration]
    timeout-minutes: 15
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6

      - name: Install Go
        uses: actions/setup-go@4b73464bb391d4059bd26b0524d20df3927bd417 # v6
        with:
          go-version-file: 'go.mod'
          cache: true

      - name: Build
        run: make build

      - name: Start server
        run: |
          go run main.go -env-file .env &
          sleep 6

      - name: OWASP ZAP API Scan
        uses: zaproxy/action-api-scan@v0.9.0
        with:
          target: 'http://localhost:8080/swagger/doc.json'
          format: openapi
          fail_action: false
```

Note: `fail_action: false` initially to collect baseline findings without blocking CI. Set to `true` once findings are triaged.

---

## Phase 7 — Container Image Scanning

**Tools**: Trivy (via GitHub Action)

**What**: Scans built Docker images for OS package and application dependency vulnerabilities before push.

**Note**: Trivy is **not** installed via `make deps` — it runs only in CI via the `aquasecurity/trivy-action` GitHub Action. No local install required (though developers can install it locally via their package manager if desired).

**Changes required**:

### 7.1 — CI: new `image-scan` job in `.github/workflows/ci.yml`

```yaml
  image-scan:
    needs: [builds]
    timeout-minutes: 10
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6

      - name: Build Docker image
        run: docker build -t flight-path:scan .

      - name: Trivy image scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'flight-path:scan'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
```

### 7.2 — CI: filesystem scan in `static-check` job

```yaml
      - name: Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
```

---

## Phase 8 — Consolidate `make critic` into `golangci-lint`

**What**: `gocritic` is already included as a linter inside `golangci-lint` and is now enabled via `.golangci.yml` with all four check categories (diagnostic, style, performance, opinionated). The standalone `make critic` target is redundant.

**Changes required**:

### 8.1 — Makefile: remove `critic` target

Remove:
```makefile
critic: deps
	go install -v github.com/go-critic/go-critic/cmd/gocritic@latest
	gocritic check -enableAll ./...
```

### 8.2 — Makefile: update `build` and `image-build` targets

```makefile
build: deps lint sec vulncheck secrets api-docs
image-build: deps api-docs lint sec vulncheck secrets
```

### 8.3 — CI: remove `critic` from `static-check`

```yaml
      - name: staticcheck
        run: |
          export PATH=$PATH:/home/runner/go/bin
          make deps lint sec vulncheck secrets lint-ci
```

---

## Summary: File Change Matrix

| File | Phase | Action |
|------|-------|--------|
| `.golangci.yml` | 1 | Create (DONE) |
| `main.go` | 1 | Auto-fix imports |
| `internal/handlers/flight.go` | 1 | Auto-fix imports |
| `internal/routes/flight.go` | 1 | Auto-fix imports |
| `internal/routes/healthcheck.go` | 1 | Auto-fix imports |
| `Makefile` | 2,3,4,5,8 | Add `vulncheck`, `secrets`, `lint-ci`, `fuzz` targets; update `deps`, `build`, `image-build`; remove `critic` |
| `internal/handlers/api_fuzz_test.go` | 5 | Create (new file) |
| `.github/workflows/ci.yml` | 2,3,4,6,7 | Add `vulncheck`, `secrets`, `lint-ci` to static-check; add `dast` and `image-scan` jobs; add Trivy fs scan |
| `README.md` | All | Update to reflect new commands and CI pipeline |

---

## Updated Pre-commit Checklist

```bash
make lint && make sec && make vulncheck && make secrets && make test && make api-docs && make build
```

---

## Implementation Order

Phases can be implemented independently, but the recommended order is:

1. **Phase 1** — `.golangci.yml` + import fixes (foundation for all other linting)
2. **Phase 8** — Consolidate `critic` into `golangci-lint` (cleanup before adding more)
3. **Phase 2** — `govulncheck` (highest-value security addition)
4. **Phase 3** — `gitleaks` (secrets detection)
5. **Phase 4** — `actionlint` (CI hygiene)
6. **Phase 5** — Fuzz testing (algorithmic safety net)
7. **Phase 6** — OWASP ZAP DAST (runtime security)
8. **Phase 7** — Trivy container scanning (supply chain)
