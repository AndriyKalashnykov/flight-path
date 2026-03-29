# SAST, DAST, Linting & Security Tools Analysis

## Current State

### SAST (Static Application Security Testing)

| Tool | In Use | Where | What It Does |
|------|--------|-------|--------------|
| **gosec** | Yes | `make sec`, CI (`static-check` job) | Go-specific security scanner. Checks for SQL injection, hardcoded credentials, insecure crypto, file permissions, command injection, etc. |
| **go vet** | Partial | Invoked indirectly via `golangci-lint` | Built-in Go static analysis. Catches suspicious constructs (printf format mismatches, unreachable code, bad struct tags). |

**Assessment**: Basic SAST coverage. `gosec` covers Go-specific vulnerability patterns but there is no supply-chain analysis (dependency CVE scanning), no secrets detection, and no container image scanning.

### DAST (Dynamic Application Security Testing)

| Tool | In Use | Where | What It Does |
|------|--------|-------|--------------|
| **Newman/Postman** | Yes | `make e2e`, CI (`integration` job) | Functional API testing (6 test cases). Tests correct responses and error handling but does **not** perform security-focused dynamic testing. |

**Assessment**: No DAST tooling. Newman tests validate functional correctness, not security. There is no fuzzing, no automated attack simulation, and no runtime vulnerability scanning against the running API.

### Linting

| Tool | In Use | Where | What It Does |
|------|--------|-------|--------------|
| **golangci-lint** | Yes | `make lint`, CI (`static-check` job) | Meta-linter aggregating 100+ Go linters (staticcheck, errcheck, ineffassign, govet, etc.). No `.golangci.yml` config file — runs with defaults. |
| **gocritic** | Yes | `make critic`, CI (`static-check` job) | Opinionated Go linter with style, performance, and diagnostic checks. Runs with `-enableAll`. |

**Assessment**: Good linting coverage. Two complementary linters catch a wide range of code quality and correctness issues. Missing: a `.golangci.yml` configuration to enable additional linters beyond defaults (e.g., `exhaustive`, `gocyclo`, `dupl`, `bodyclose`).

### Security Scanning

| Tool | In Use | Where | What It Does |
|------|--------|-------|--------------|
| **gosec** | Yes | `make sec`, CI | Go source code security scanner (see SAST above). |

**Assessment**: No dependency vulnerability scanning (`go.mod`/`go.sum` CVE checks). No container image scanning. No secrets detection in source code or git history.

---

## Gaps Identified

| Gap | Risk | Priority |
|-----|------|----------|
| No dependency vulnerability scanning | Known CVEs in transitive deps go undetected | **High** |
| No container image scanning | Vulnerable base images or binaries ship to production | **High** |
| No secrets detection | Hardcoded secrets could leak to VCS | **High** |
| No DAST / API fuzzing | Runtime vulnerabilities (injection, auth bypass) go undetected | **Medium** |
| No SBOM generation | Cannot audit software supply chain | **Medium** |
| No `.golangci.yml` config | Missing linters that defaults don't enable | **Low** |
| No license compliance scanning | Potential license violations in dependencies | **Low** |

---

## Recommended Tools

### SAST

| Tool | License | Why | Integration |
|------|---------|-----|-------------|
| **[gosec](https://github.com/securego/gosec)** (keep) | Apache-2.0 | Already in use. Best-in-class Go SAST scanner. | `make sec` / CI |
| **[semgrep](https://github.com/semgrep/semgrep)** | LGPL-2.1 | Language-agnostic SAST with Go rulesets. Complements gosec with custom rules. Detects OWASP Top 10 patterns. | `semgrep scan --config auto .` |
| **[govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck)** | BSD-3 | Official Go tool for known vulnerability detection in dependencies. Uses the Go vulnerability database. | `govulncheck ./...` |
| **[trivy](https://github.com/aquasecurity/trivy)** | Apache-2.0 | Scans source code, dependencies (`go.mod`), container images, IaC, and secrets — all in one tool. | `trivy fs .` / `trivy image <image>` |

**Top Pick**: Add **govulncheck** (lightweight, Go-official) + **trivy** (comprehensive scanner covering deps, containers, secrets, and IaC).

### DAST

| Tool | License | Why | Integration |
|------|---------|-----|-------------|
| **[OWASP ZAP](https://github.com/zaproxy/zaproxy)** | Apache-2.0 | Industry-standard DAST. Automated active/passive scanning, API scanning via OpenAPI spec import, CI-friendly Docker image. | `docker run -t zaproxy/zap-stable zap-api-scan.py -t http://localhost:8080/swagger/doc.json -f openapi` |
| **[Nuclei](https://github.com/projectdiscovery/nuclei)** | MIT | Fast, template-based vulnerability scanner. Large community template library. Good for targeted API checks. | `nuclei -u http://localhost:8080 -t http/` |
| **[go-fuzz / native fuzzing](https://go.dev/doc/security/fuzz)** | BSD-3 | Built into Go 1.18+. Fuzz-test the `FindItinerary` function and HTTP handlers for panics and edge cases. | `go test -fuzz=FuzzFindItinerary ./internal/handlers/` |

**Top Pick**: Add **Go native fuzzing** (zero-dependency, tests core algorithm) + **OWASP ZAP** (can import the existing Swagger spec for automated API security scanning).

### Linting

| Tool | License | Why | Integration |
|------|---------|-----|-------------|
| **[golangci-lint](https://github.com/golangci/golangci-lint)** (keep) | GPL-3.0 | Already in use. Add a `.golangci.yml` to enable more linters. | `make lint` / CI |
| **[gocritic](https://github.com/go-critic/go-critic)** (keep) | MIT | Already in use. Good complement to golangci-lint. | `make critic` / CI |
| **[nilaway](https://github.com/uber-go/nilaway)** | Apache-2.0 | Detects nil pointer dereferences statically. Catches a class of bugs that other linters miss. | Add as golangci-lint plugin or run standalone. |
| **[actionlint](https://github.com/rhysd/actionlint)** | MIT | Lints GitHub Actions workflow files. Catches common CI/CD misconfigurations. | `actionlint` |

**Top Pick**: Add a `.golangci.yml` enabling additional linters (`exhaustive`, `bodyclose`, `gocyclo`, `dupl`, `nilaway`). Add **actionlint** for CI workflow validation.

### Security & Supply Chain

| Tool | License | Why | Integration |
|------|---------|-----|-------------|
| **[trivy](https://github.com/aquasecurity/trivy)** | Apache-2.0 | All-in-one: dependency CVEs, container image scanning, secrets detection, SBOM generation, IaC misconfiguration. | `trivy fs .` / `trivy image andriykalashnykov/flight-path:latest` |
| **[gitleaks](https://github.com/gitleaks/gitleaks)** | MIT | Scans git history and working tree for hardcoded secrets (API keys, tokens, passwords). Pre-commit hook support. | `gitleaks detect --source .` |
| **[syft](https://github.com/anchore/syft)** + **[grype](https://github.com/anchore/grype)** | Apache-2.0 | SBOM generation (syft) + vulnerability scanning (grype). More focused alternative to trivy for supply chain. | `syft . -o spdx-json > sbom.json && grype sbom:sbom.json` |
| **[cosign](https://github.com/sigstore/cosign)** | Apache-2.0 | Container image signing and verification. Ensures image integrity in the supply chain. | `cosign sign <image>` |

**Top Pick**: Add **trivy** (covers deps + images + secrets in one tool) + **gitleaks** (pre-commit hook for secrets).

---

## Recommended Implementation Plan

### Phase 1 — Quick Wins (Makefile + CI)

```makefile
# Add to Makefile:

vulncheck: deps
	go install golang.org/x/vuln/cmd/govulncheck@latest
	govulncheck ./...

secrets: deps
	@command -v gitleaks >/dev/null 2>&1 || go install github.com/zricethezav/gitleaks/v8@latest
	gitleaks detect --source . --verbose

scan: deps
	@command -v trivy >/dev/null 2>&1 || { echo "Install trivy: https://aquasecurity.github.io/trivy"; exit 1; }
	trivy fs --scanners vuln,secret,misconfig .

scan-image:
	trivy image andriykalashnykov/flight-path:latest
```

Update pre-commit checklist:
```bash
make lint && make critic && make sec && make vulncheck && make secrets && make test && make api-docs && make build
```

### Phase 2 — CI Pipeline Enhancement

Add to `.github/workflows/ci.yml`:

```yaml
  security-scan:
    needs: [static-check]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-go@v6
        with:
          go-version-file: 'go.mod'
      - name: govulncheck
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...
      - name: Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
      - name: Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Phase 3 — DAST & Fuzzing

1. Add fuzz tests to `internal/handlers/`:
```go
func FuzzFindItinerary(f *testing.F) {
    f.Add("SFO", "ATL", "ATL", "EWR")
    f.Fuzz(func(t *testing.T, s1, d1, s2, d2 string) {
        flights := []api.Flight{{Start: s1, End: d1}, {Start: s2, End: d2}}
        FindItinerary(flights) // must not panic
    })
}
```

2. Add OWASP ZAP API scan (uses existing Swagger spec):
```yaml
  dast:
    needs: [integration]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Build and start server
        run: |
          make build
          go run main.go -env-file .env &
          sleep 6
      - name: OWASP ZAP API Scan
        uses: zaproxy/action-api-scan@v0.9.0
        with:
          target: 'http://localhost:8080/swagger/doc.json'
          format: openapi
```

### Phase 4 — Container Supply Chain

1. Add trivy image scanning to the `image-build` workflow
2. Add SBOM generation with syft
3. Consider image signing with cosign for release images

---

## Summary Matrix

| Category | Current Tools | Recommended Additions | Priority |
|----------|--------------|----------------------|----------|
| **SAST** | gosec | govulncheck, semgrep (optional) | High |
| **DAST** | _(none)_ | OWASP ZAP, Go native fuzzing | Medium |
| **Linting** | golangci-lint, gocritic | .golangci.yml config, nilaway, actionlint | Low |
| **Deps/CVE** | _(none)_ | govulncheck, trivy | High |
| **Secrets** | _(none)_ | gitleaks, trivy | High |
| **Container** | _(none)_ | trivy image scan | High |
| **SBOM** | _(none)_ | syft + grype (or trivy) | Medium |
| **E2E Security** | Newman (functional only) | OWASP ZAP API scan | Medium |
