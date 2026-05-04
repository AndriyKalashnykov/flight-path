.DEFAULT_GOAL := help
SHELL := /bin/bash

APP_NAME       := flight-path
CURRENTTAG     := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
GOFLAGS        ?= -mod=mod
GOOS           ?= linux
GOARCH         ?= amd64
NEWMANTESTSLOCATION := ./test/

# GHCR publishing identity (override via env when pushing from CI or alt account)
GHCR_USER ?= $(shell git config --get user.name 2>/dev/null | tr '[:upper:]' '[:lower:]')
GHCR_REPO ?= $(GHCR_USER)/$(APP_NAME)

HOMEDIR := $(CURDIR)
OUTDIR  := $(HOMEDIR)/output
COVPROF := $(HOMEDIR)/covprof.out

# === Go Version (from go.mod — tracked by Renovate's gomod manager, not here) ===
GO_VERSION := $(shell grep -oP '^go \K[0-9.]+' go.mod)

# === Tool Versions ===
# The project's quality/security toolchain (golangci-lint, gosec, govulncheck,
# gitleaks, actionlint, shellcheck, hadolint, trivy, act, goreleaser) is pinned
# in .mise.toml — one source of truth, consumed by both local dev and CI
# (jdx/mise-action). Do NOT re-pin those tools here.
#
# The remaining Makefile-level pins are for tools that mise does not manage:
# Go-installed tools without a stable aqua backend, and Docker-image tools.

# renovate: datasource=github-releases depName=swaggo/swag
SWAG_VERSION        := 2.0.0-rc5
# renovate: datasource=go depName=golang.org/x/perf/cmd/benchstat versioning=loose
BENCHSTAT_VERSION   := 0.0.0-20260409210113-8e83ce0f7b1c
# NODE_VERSION tracks major only — source of truth: .nvmrc (Renovate cannot track major-only values).
# Node is installed via mise (.mise.toml pins `node = "24"`); .nvmrc is kept for mise's native read.
NODE_VERSION        := $(shell cat .nvmrc 2>/dev/null || echo 24)
# pnpm is pinned in test/package.json via the `packageManager` field (corepack auto-switches).
# renovate: datasource=github-releases depName=jdx/mise
MISE_VERSION        := 2026.4.11
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION := 11.12.0

# Ensure tools installed to ~/.local/bin (mise bootstrap lives here) AND mise's
# shim dir (hadolint, trivy, act, goreleaser, golangci-lint, gosec, gitleaks,
# actionlint, shellcheck, govulncheck) are on PATH for every recipe — needed
# inside the act runner container where neither path is preconfigured.
# Exported so every sub-shell the recipes spawn inherits it.
export PATH := $(HOME)/.local/bin:$(HOME)/.local/share/mise/shims:$(PATH)

# === Go version management: mise (https://mise.jdx.dev) ===
# mise auto-activates via shell hook, reads .mise.toml, and publishes semver releases
# trackable by Renovate. CI uses jdx/mise-action (reads .mise.toml directly).
HAS_MISE := $(shell command -v mise >/dev/null 2>&1 && echo true || echo false)
define go-exec
$(if $(filter true,$(HAS_MISE)),bash -c 'eval "$$(mise activate bash --shims)" && $(1)',bash -c '$(1)')
endef

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-22s\033[0m - %s\n", $$1, $$2}'

#deps: @ Download and install dependencies
deps:
	@# Install mise if not present (local development only; CI uses jdx/mise-action)
	@if [ -z "$$CI" ] && ! command -v mise >/dev/null 2>&1; then \
		echo "Installing mise v$(MISE_VERSION)..."; \
		curl -fsSL https://mise.jdx.dev/install.sh | MISE_VERSION=v$(MISE_VERSION) bash; \
		echo ""; \
		echo "mise installed. Activate by adding to your shell rc:"; \
		echo "  eval \"\$$(mise activate bash)\"  # or zsh/fish"; \
		echo "Then re-run 'make deps' to install the toolchain pinned in .mise.toml."; \
		exit 0; \
	fi
	@# mise install reads .mise.toml and provisions go, node, and every quality/
	@# security tool (golangci-lint, gosec, govulncheck, gitleaks, actionlint,
	@# shellcheck, hadolint, trivy, act, goreleaser) in one pass. Idempotent.
	@if [ "$(HAS_MISE)" = "true" ]; then \
		mise install --yes; \
	else \
		command -v go >/dev/null 2>&1 || { echo "Error: Go required. Install mise from https://mise.jdx.dev or Go from https://go.dev/dl/"; exit 1; }; \
	fi
	@# Tools that don't have a stable mise backend stay Go-installed.
	@$(call go-exec,command -v swag) >/dev/null 2>&1 || { echo "Installing swag..."; $(call go-exec,go install github.com/swaggo/swag/v2/cmd/swag@v$(SWAG_VERSION)); }
	@$(call go-exec,command -v benchstat) >/dev/null 2>&1 || { echo "Installing benchstat..."; $(call go-exec,go install golang.org/x/perf/cmd/benchstat@v$(BENCHSTAT_VERSION)); }
	@command -v node >/dev/null 2>&1 || { \
		echo "Error: Node.js not found. Install mise (https://mise.jdx.dev), then run 'mise install' — .mise.toml pins node=$(NODE_VERSION)."; \
		exit 1; \
	}
	@command -v pnpm >/dev/null 2>&1 || { echo "Enabling pnpm via corepack (version from test/package.json packageManager)..."; corepack enable; }
	@[ -f test/node_modules/.bin/newman ] || { echo "Installing newman..."; cd test && pnpm install; }

#deps-check: @ Show required Go version and tool status
deps-check:
	@echo "Go version required: $(GO_VERSION)"
	@if command -v mise >/dev/null 2>&1; then mise list 2>/dev/null || echo "mise: .mise.toml not trusted — run 'mise trust'"; else echo "mise not installed - install from https://mise.jdx.dev"; fi
	@echo "--- Tool status ---"
	@for tool in swag benchstat golangci-lint gosec govulncheck gitleaks actionlint shellcheck hadolint trivy act goreleaser container-structure-test node pnpm; do \
		printf "  %-16s " "$$tool:"; \
		command -v $$tool >/dev/null 2>&1 && echo "installed" || echo "NOT installed"; \
	done

#api-docs: @ Build source code for swagger api reference
api-docs: deps
	@$(call go-exec,swag init --parseDependency -g main.go)

#test: @ Run unit + handler tests
test: deps
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -v ./...)

#integration-test: @ Run integration tests (full HTTP stack via httptest, CORS/middleware/error paths)
integration-test: deps
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -tags=integration -v ./internal/app/...)

#fuzz: @ Run fuzz tests for 30 seconds
fuzz: deps
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test ./internal/handlers/ -fuzz=FuzzFindItinerary -fuzztime=30s)

#bench: @ Run bench tests
bench: deps
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s)

#bench-save: @ Save benchmark results to file
bench-save: deps
	@mkdir -p benchmarks
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s) | tee benchmarks/bench_$(shell date +%Y%m%d_%H%M%S).txt

#bench-compare: @ Compare two benchmark files (usage: make bench-compare OLD=file1.txt NEW=file2.txt)
bench-compare: deps
	@if [ -z "$(OLD)" ] || [ -z "$(NEW)" ]; then \
		NEW_FILE=$$(ls -t benchmarks/bench_*.txt 2>/dev/null | head -n 1); \
		OLD_FILE=$$(ls -t benchmarks/bench_*.txt 2>/dev/null | head -n 2 | tail -n 1); \
		if [ -z "$$NEW_FILE" ] || [ -z "$$OLD_FILE" ]; then \
			echo "Error: Not enough benchmark files found in ./benchmarks/"; \
			echo "Run 'make bench-save' at least twice to create benchmark files"; \
			exit 1; \
		fi; \
		echo "Comparing: $$OLD_FILE (old) vs $$NEW_FILE (new)"; \
		export OLD_FILE NEW_FILE; \
		$(call go-exec,benchstat "$$OLD_FILE" "$$NEW_FILE"); \
	else \
		$(call go-exec,benchstat $(OLD) $(NEW)); \
	fi

#lint: @ Run golangci-lint and hadolint (comprehensive linting via .golangci.yml)
lint: deps lint-scripts-exec
	@$(call go-exec,golangci-lint run ./...)
	@hadolint Dockerfile

#lint-scripts-exec: @ Verify all shell scripts are executable (catches subagent 0644 writes)
lint-scripts-exec:
	@NONEXEC=$$(find scripts -name '*.sh' -not -executable -print 2>/dev/null); \
	if [ -n "$$NONEXEC" ]; then \
		echo "Error: shell scripts missing +x:"; \
		echo "$$NONEXEC" | sed 's/^/  /'; \
		echo "Fix with: chmod +x <file>"; \
		exit 1; \
	fi

#vulncheck: @ Run Go vulnerability check on dependencies
vulncheck: deps
	@$(call go-exec,govulncheck ./...)

#secrets: @ Scan for hardcoded secrets in source code and git history
secrets: deps
	@$(call go-exec,gitleaks detect --source . --verbose --redact)

#sec: @ Run gosec security scanner
sec: deps
	@$(call go-exec,gosec ./...)

#lint-ci: @ Lint GitHub Actions workflow files
lint-ci: deps
	@$(call go-exec,actionlint)

#format: @ Format Go code (rewrites files in place; for dev use)
format: deps
	@$(call go-exec,gofmt -l -w .)

#format-check: @ Verify Go code is gofmt-clean (CI gate; non-mutating, exits non-zero on diff)
format-check: deps
	@DIFF=$$($(call go-exec,gofmt -l .)); \
	if [ -n "$$DIFF" ]; then \
		echo "ERROR: gofmt would rewrite the following files. Run 'make format'."; \
		echo "$$DIFF"; \
		exit 1; \
	fi

#release-check: @ Validate .goreleaser.yml syntax and config
release-check: deps
	@goreleaser check

#static-check: @ Run code static check
static-check: format-check lint-ci lint sec vulncheck secrets trivy-fs mermaid-lint release-check
	@echo "Static check passed."

#build: @ Build REST API server's binary
build: deps api-docs
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) && go build -a -o server main.go)

#run: @ Run REST API locally
run: deps build
	@export TZ="UTC"; ./server -env-file .env

#image-build: @ Build Docker image for local testing
image-build: build
	@docker buildx build --load \
		--build-arg GOMODCACHE=$$($(call go-exec,go env GOMODCACHE)) \
		--build-arg GOCACHE=$$($(call go-exec,go env GOCACHE)) \
		-t $(APP_NAME):local .

#image-run: @ Run Docker container locally (assumes image built; run `make image-build` first if needed)
image-run: image-stop
	@docker run --rm -d --name $(APP_NAME) -p 8080:8080 -e SERVER_PORT=8080 \
		--entrypoint sh $(APP_NAME):local -c "touch /tmp/.env && /main -env-file /tmp/.env"

#image-stop: @ Stop the locally running Docker container
image-stop:
	@docker stop $(APP_NAME) 2>/dev/null || true
	@docker rm -f $(APP_NAME) 2>/dev/null || true

#image-push: @ Push Docker image to GHCR (requires GH_ACCESS_TOKEN and GHCR_USER)
image-push: image-build
	@if [ -z "$$GH_ACCESS_TOKEN" ]; then echo "Error: GH_ACCESS_TOKEN not set"; exit 1; fi
	@if [ -z "$(GHCR_USER)" ]; then echo "Error: GHCR_USER not set and git user.name unavailable"; exit 1; fi
	@echo "$$GH_ACCESS_TOKEN" | docker login ghcr.io -u "$(GHCR_USER)" --password-stdin
	@docker tag $(APP_NAME):local ghcr.io/$(GHCR_REPO):$(CURRENTTAG)
	@docker push ghcr.io/$(GHCR_REPO):$(CURRENTTAG)

#image-smoke-test: @ Smoke-test a pre-built Docker container (no rebuild)
image-smoke-test:
	@docker run -d --name fp-test -p 8080:8080 -e SERVER_PORT=8080 \
		--entrypoint sh $(APP_NAME):local -c "touch /tmp/.env && /main -env-file /tmp/.env"; \
	RESULT=0; \
	for i in $$(seq 1 10); do curl -sf http://localhost:8080/ >/dev/null 2>&1 && break; sleep 1; done; \
	curl -sf http://localhost:8080/ && echo "Health: OK" || { echo "Health: FAIL"; docker logs fp-test; RESULT=1; }; \
	curl -sf -X POST http://localhost:8080/calculate \
		-H 'Content-Type: application/json' \
		-d '[["SFO","ATL"],["ATL","EWR"]]' && echo "API: OK" || { echo "API: FAIL"; docker logs fp-test; RESULT=1; }; \
	docker rm -f fp-test 2>/dev/null || true; \
	exit $$RESULT

#image-structure-test: @ Validate Dockerfile metadata + binary properties (container-structure-test)
image-structure-test: deps
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required for image-structure-test"; exit 1; }
	@$(call go-exec,container-structure-test test --image $(APP_NAME):local --config container-structure-test.yaml)

#image-test: @ Build and smoke-test Docker container
image-test: image-build image-smoke-test image-structure-test

#image-scan: @ Build Docker image and run Trivy scan (requires trivy)
image-scan: deps build
	@docker buildx build --load \
		--build-arg GOMODCACHE=/go/pkg/mod \
		--build-arg GOCACHE=/root/.cache/go-build \
		-t $(APP_NAME):scan .
	@trivy image --severity CRITICAL,HIGH --exit-code 1 $(APP_NAME):scan

#release: @ Create and push a new tag
release: ci
	@git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 || { \
		echo "Error: current branch has no upstream. Set one with 'git push -u origin $$(git symbolic-ref --short HEAD)' before releasing."; \
		exit 1; \
	}
	@NT=$$(bash -c 'read -p "Please provide a new tag (current tag - $(CURRENTTAG)): " newtag; echo $$newtag'); \
	echo "$$NT" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: Tag must match vN.N.N"; exit 1; }; \
	read -p "Are you sure to create and push $$NT tag? [y/N] " ans; [ "$${ans:-N}" = y ] || exit 1; \
	echo "$$NT" > ./pkg/api/version.txt; \
	git add pkg/api/version.txt; \
	git commit -s -m "Cut $$NT release"; \
	git tag "$$NT"; \
	git push origin "$$NT"; \
	git push; \
	echo "Done."

#update: @ Update dependencies to latest versions
update: deps
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) && go get -u ./... && go mod tidy)

# === Platform Detection ===
OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

#open-swagger: @ Open browser with Swagger docs pointing to localhost
open-swagger:
	@$(OPEN_CMD) http://localhost:8080/swagger/index.html 1>/dev/null 2>&1

#test-case-one: @ Test case #1 [["SFO", "EWR"]]
test-case-one:
	@curl -X 'POST' \
	      'http://localhost:8080/calculate' \
	      -H 'accept: application/json' \
	      -H 'Content-Type: application/json' \
	      -d '[["SFO", "EWR"]]'

#test-case-two: @ Test case #2 [["ATL", "EWR"], ["SFO", "ATL"]]
test-case-two:
	@curl -X 'POST' \
	      'http://localhost:8080/calculate' \
	      -H 'accept: application/json' \
	      -H 'Content-Type: application/json' \
	      -d '[["ATL", "EWR"], ["SFO", "ATL"]]'

#test-case-three: @ Test case #3 [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
test-case-three:
	@curl -X 'POST' \
	      'http://localhost:8080/calculate' \
	      -H 'accept: application/json' \
	      -H 'Content-Type: application/json' \
	      -d '[["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]'

#clean: @ Remove build artifacts and test cache
clean:
	@rm -f server
	@rm -rf $(OUTDIR)
	@rm -f $(COVPROF)
	@$(call go-exec,go clean -testcache) 2>/dev/null || true

#coverage: @ Run unit + integration tests with coverage report
coverage: deps
	@mkdir -p $(OUTDIR)
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -tags=integration -coverpkg=./internal/... -coverprofile=$(COVPROF) -covermode=atomic ./internal/...)
	@$(call go-exec,go tool cover -func=$(COVPROF))
	@$(call go-exec,go tool cover -html=$(COVPROF) -o $(OUTDIR)/coverage.html)
	@echo "Coverage report: $(OUTDIR)/coverage.html"

#coverage-check: @ Verify coverage meets 80% threshold
coverage-check: coverage
	@TOTAL=$$($(call go-exec,go tool cover -func=$(COVPROF)) | grep total | awk '{print $$3}' | tr -d '%'); \
	echo "Coverage: $${TOTAL}%"; \
	if awk "BEGIN {exit !($${TOTAL} < 80)}"; then \
		echo "FAIL: Coverage $${TOTAL}% is below 80% threshold"; exit 1; \
	else \
		echo "PASS: Coverage meets 80% threshold"; \
	fi

#ci: @ Run full CI pipeline locally (unit + static + build + fuzz + prune-check).
# For full e2e validation via Newman, use `make ci-run` which drives act
# through the `e2e` job (Newman runs against the built binary).
ci: deps static-check test integration-test coverage-check build fuzz deps-prune-check
	@echo "Local CI pipeline passed."

#ci-run: @ Run GitHub Actions workflow locally using act
# Synthetic push-event payload (--eventpath) gives dorny/paths-filter the
# repository.default_branch field act omits by default — without it, the
# `changes` detector job errors and every downstream gated job is blocked.
# The all-zero before/after SHAs make dorny treat the push as the initial
# commit and report every file as changed, so `code=true` and every job
# runs — desired behavior for local CI (opposite of the doc-only-skip
# behavior on GitHub).
ci-run: deps
	@docker container prune -f 2>/dev/null || true
	@EVENT=$$(mktemp /tmp/act-push-event.XXXXXX.json); \
	printf '{"repository":{"default_branch":"main"},"ref":"refs/heads/main","before":"0000000000000000000000000000000000000000","after":"0000000000000000000000000000000000000000"}' > $$EVENT; \
	if [ -f ~/.secrets ]; then . ~/.secrets; fi; \
	ACT_PORT=$$(shuf -i 40000-59999 -n 1); \
	ARTIFACT_PATH=$$(mktemp -d -t act-artifacts.XXXXXX); \
	secret_args=(); \
	if [ -n "$$GITHUB_TOKEN" ]; then secret_args+=(--secret GITHUB_TOKEN); fi; \
	RC=0; \
	for job in static-check build test integration-test e2e docker; do \
		echo "=== act job: $$job ==="; \
		act push -W .github/workflows/ci.yml \
			--job $$job \
			--eventpath $$EVENT \
			--container-architecture linux/amd64 \
			--pull=false \
			--artifact-server-port "$$ACT_PORT" \
			--artifact-server-path "$$ARTIFACT_PATH" \
			--var ACT=true \
			"$${secret_args[@]}" || { RC=$$?; break; }; \
	done; \
	rm -f $$EVENT; \
	rm -rf "$$ARTIFACT_PATH"; \
	exit $$RC

#check: @ Run pre-commit checklist (alias for ci)
check: ci
	@echo "All pre-commit checks passed."

#trivy-fs: @ Run Trivy filesystem vulnerability scan
trivy-fs: deps
	@trivy fs \
		--scanners vuln,secret,misconfig \
		--severity CRITICAL,HIGH \
		--skip-dirs test/node_modules,.pnpm-store \
		--exit-code 1 .

#trivy-image: @ Run Trivy image vulnerability scan
trivy-image: deps
	@trivy image --severity CRITICAL,HIGH --exit-code 1 $(APP_NAME):scan

#e2e: @ Build + start server + run e2e + stop server (self-contained; called by `make ci`)
# Allocates an ephemeral port via scripts/pick-port.sh so parallel runs
# (two checkouts, sibling repos under a single dev machine, multi-job CI)
# don't collide on a fixed 8080. Newman gets baseUrl via --env-var.
e2e: deps build
	@PORT=$$(./scripts/pick-port.sh); \
		BASE="http://localhost:$$PORT"; \
		PIDFILE=$$(mktemp -t flight-path-e2e.XXXXXX.pid); \
		SERVER_PORT=$$PORT ./server -env-file .env >/tmp/flight-path-e2e.log 2>&1 & echo $$! > "$$PIDFILE"; \
		./scripts/wait-for-server.sh "$$BASE/" 30; \
		EXIT=0; \
		./test/node_modules/.bin/newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json \
			--env-var "baseUrl=$$BASE" || EXIT=$$?; \
		kill "$$(cat "$$PIDFILE")" 2>/dev/null || true; \
		rm -f "$$PIDFILE"; \
		exit $$EXIT

#e2e-quick: @ Run Postman/Newman end-to-end tests (requires server already running)
e2e-quick: deps
	@curl -sf http://localhost:8080/ >/dev/null 2>&1 || { echo "Error: Server not running on port 8080. Start with 'make run &' first."; exit 1; }
	@./test/node_modules/.bin/newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json

#renovate-validate: @ Validate Renovate configuration
renovate-validate: deps
	@pnpm dlx renovate --platform=local

#mermaid-lint: @ Validate Mermaid diagrams in markdown files
mermaid-lint:
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required for mermaid-lint"; exit 1; }
	@set -euo pipefail; \
	MD_FILES=$$(grep -lF '```mermaid' README.md CLAUDE.md docs/*.md specs/*.md 2>/dev/null || true); \
	if [ -z "$$MD_FILES" ]; then \
		echo "No Mermaid blocks found — skipping."; \
		exit 0; \
	fi; \
	FAILED=0; \
	for md in $$MD_FILES; do \
		echo "Validating Mermaid blocks in $$md..."; \
		LOG=$$(mktemp); \
		if docker run --rm -v "$$PWD:/data" \
			minlag/mermaid-cli:$(MERMAID_CLI_VERSION) \
			-i "/data/$$md" -o "/tmp/$$(basename $$md .md).svg" >"$$LOG" 2>&1; then \
			echo "  [OK] All blocks rendered cleanly."; \
		else \
			echo "  [FAIL] Parse error in $$md:"; \
			sed 's/^/    /' "$$LOG"; \
			FAILED=$$((FAILED + 1)); \
		fi; \
		rm -f "$$LOG"; \
	done; \
	if [ "$$FAILED" -gt 0 ]; then \
		echo "Mermaid lint: $$FAILED file(s) had parse errors."; \
		exit 1; \
	fi

#deps-prune: @ Remove unused Go module dependencies (Go-only project; no other ecosystems to prune)
deps-prune: deps
	@echo "=== Dependency Pruning ==="
	@echo "--- Go: running go mod tidy ---"
	@$(call go-exec,go mod tidy)
	@echo "=== Pruning complete ==="

#deps-prune-check: @ Verify no prunable dependencies (CI gate)
deps-prune-check: deps
	@$(call go-exec,go mod tidy)
	@if ! git diff --exit-code go.mod go.sum >/dev/null 2>&1; then \
		echo "ERROR: go.mod/go.sum not tidy. Run 'make deps-prune'."; \
		git checkout go.mod go.sum; \
		exit 1; \
	fi
	@echo "No prunable dependencies found."

.PHONY: help deps deps-check api-docs test integration-test fuzz bench bench-save bench-compare \
	lint lint-scripts-exec vulncheck secrets sec lint-ci format format-check static-check mermaid-lint release-check build run release update open-swagger \
	test-case-one test-case-two test-case-three e2e e2e-quick clean coverage coverage-check \
	ci ci-run check trivy-fs trivy-image \
	image-build image-run image-stop image-push image-smoke-test image-structure-test image-test image-scan \
	renovate-validate deps-prune deps-prune-check
