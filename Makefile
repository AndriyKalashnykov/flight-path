.DEFAULT_GOAL := help

APP_NAME       := flight-path
CURRENTTAG     := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
NEWTAG         ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - ${CURRENTTAG}): " newtag; echo $$newtag')
GOFLAGS        ?= -mod=mod
GOOS           ?= linux
GOARCH         ?= amd64
NEWMANTESTSLOCATION := ./test/

HOMEDIR := $(CURDIR)
OUTDIR  := $(HOMEDIR)/output
COVPROF := $(HOMEDIR)/covprof.out

# === Go Version (from go.mod — tracked by Renovate's gomod manager, not here) ===
GO_VERSION := $(shell grep -oP '^go \K[0-9.]+' go.mod)

# === Tool Versions (pinned) ===
# renovate: datasource=github-releases depName=swaggo/swag
SWAG_VERSION        := 2.0.0-rc5
# renovate: datasource=github-releases depName=securego/gosec
GOSEC_VERSION       := 2.25.0
# renovate: datasource=go depName=golang.org/x/perf/cmd/benchstat versioning=loose
BENCHSTAT_VERSION   := 0.0.0-20260312031701-16a31bc5fbd0
# renovate: datasource=github-releases depName=golangci/golangci-lint
GOLANGCI_VERSION    := 2.11.4
# renovate: datasource=go depName=golang.org/x/vuln/cmd/govulncheck
GOVULNCHECK_VERSION := 1.1.4
# renovate: datasource=github-releases depName=zricethezav/gitleaks
GITLEAKS_VERSION    := 8.30.1
# renovate: datasource=github-releases depName=rhysd/actionlint
ACTIONLINT_VERSION  := 1.7.12
# renovate: datasource=github-releases depName=koalaman/shellcheck
SHELLCHECK_VERSION  := 0.11.0
# renovate: datasource=github-releases depName=nvm-sh/nvm
NVM_VERSION         := 0.40.4
# NODE_VERSION tracks major only — pinned manually (Renovate cannot track major-only values)
NODE_VERSION        := 24
# renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION    := 2.14.0
# renovate: datasource=github-releases depName=aquasecurity/trivy
TRIVY_VERSION       := 0.69.3
# renovate: datasource=github-releases depName=nektos/act
ACT_VERSION         := 0.2.87
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION := 11.12.0

# Ensure tools installed to ~/.local/bin (hadolint, act, shellcheck, etc.) are
# on PATH for every recipe — needed inside the act runner container where this
# path is not preconfigured. Exported so every sub-shell the recipes spawn inherits it.
export PATH := $(HOME)/.local/bin:$(PATH)

# === gvm detection ===
# gvm is a shell function (not a binary), so command -v doesn't work in Make's $(shell) context
GVM_SHA := dd652539fa4b771840846f8319fad303c7d0a8d2
HAS_GVM := $(shell [ -s "$$HOME/.gvm/scripts/gvm" ] && echo true || echo false)
define go-exec
$(if $(filter true,$(HAS_GVM)),bash -c '. $$GVM_ROOT/scripts/gvm && gvm use go$(GO_VERSION) >/dev/null && $(1)',bash -c '$(1)')
endef

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-22s\033[0m - %s\n", $$1, $$2}'

#deps: @ Download and install dependencies
deps:
	@if [ -z "$$CI" ] && [ ! -s "$$HOME/.gvm/scripts/gvm" ]; then \
		echo "Installing gvm (Go Version Manager)..."; \
		curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/$(GVM_SHA)/binscripts/gvm-installer | bash -s $(GVM_SHA); \
		echo ""; \
		echo "gvm installed. Please restart your shell or run:"; \
		echo "  source $$HOME/.gvm/scripts/gvm"; \
		echo "Then re-run 'make deps' to install Go $(GO_VERSION) via gvm."; \
		exit 0; \
	fi
	@if [ "$(HAS_GVM)" = "true" ]; then \
		bash -c '. $$GVM_ROOT/scripts/gvm && gvm list' 2>/dev/null | grep -q "go$(GO_VERSION)" || { \
			echo "Installing Go $(GO_VERSION) via gvm..."; \
			bash -c '. $$GVM_ROOT/scripts/gvm && gvm install go$(GO_VERSION) -B'; \
		}; \
	else \
		command -v go >/dev/null 2>&1 || { echo "Error: Go required. Install gvm from https://github.com/moovweb/gvm or Go from https://go.dev/dl/"; exit 1; }; \
	fi
	@$(call go-exec,command -v swag) >/dev/null 2>&1 || { echo "Installing swag..."; $(call go-exec,go install github.com/swaggo/swag/v2/cmd/swag@v$(SWAG_VERSION)); }
	@$(call go-exec,command -v gosec) >/dev/null 2>&1 || { echo "Installing gosec..."; $(call go-exec,go install github.com/securego/gosec/v2/cmd/gosec@v$(GOSEC_VERSION)); }
	@$(call go-exec,command -v benchstat) >/dev/null 2>&1 || { echo "Installing benchstat..."; $(call go-exec,go install golang.org/x/perf/cmd/benchstat@v$(BENCHSTAT_VERSION)); }
	@$(call go-exec,command -v golangci-lint) >/dev/null 2>&1 || { echo "Installing golangci-lint..."; curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $$($(call go-exec,go env GOPATH))/bin v$(GOLANGCI_VERSION); }
	@$(call go-exec,command -v govulncheck) >/dev/null 2>&1 || { echo "Installing govulncheck..."; $(call go-exec,go install golang.org/x/vuln/cmd/govulncheck@v$(GOVULNCHECK_VERSION)); }
	@$(call go-exec,command -v gitleaks) >/dev/null 2>&1 || { echo "Installing gitleaks..."; $(call go-exec,go install github.com/zricethezav/gitleaks/v8@v$(GITLEAKS_VERSION)); }
	@$(call go-exec,command -v actionlint) >/dev/null 2>&1 || { echo "Installing actionlint..."; $(call go-exec,go install github.com/rhysd/actionlint/cmd/actionlint@v$(ACTIONLINT_VERSION)); }
	@command -v node >/dev/null 2>&1 || { echo "Installing Node.js LTS via nvm..."; \
		export NVM_DIR="$${NVM_DIR:-$$HOME/.nvm}"; \
		if [ ! -s "$$NVM_DIR/nvm.sh" ]; then \
			echo "Installing nvm $(NVM_VERSION)..."; \
			curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		fi; \
		. "$$NVM_DIR/nvm.sh" && nvm install $(NODE_VERSION) && nvm use $(NODE_VERSION); \
	}
	@command -v pnpm >/dev/null 2>&1 || { echo "Installing pnpm via corepack..."; corepack enable pnpm; }
	@[ -f test/node_modules/.bin/newman ] || { echo "Installing newman..."; cd test && pnpm install; }

#deps-check: @ Show required Go version and tool status
deps-check:
	@echo "Go version required: $(GO_VERSION)"
	@command -v gvm >/dev/null 2>&1 && { \
		bash -c '. $$GVM_ROOT/scripts/gvm && gvm list'; \
	} || echo "gvm not installed - install from https://github.com/moovweb/gvm"
	@echo "--- Tool status ---"
	@for tool in swag gosec benchstat golangci-lint govulncheck gitleaks actionlint node hadolint act; do \
		printf "  %-16s " "$$tool:"; \
		command -v $$tool >/dev/null 2>&1 && echo "installed" || echo "NOT installed"; \
	done

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint $$HOME/.local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

#deps-shellcheck: @ Install shellcheck for shell script linting
deps-shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Installing shellcheck $(SHELLCHECK_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL -o /tmp/shellcheck.tar.xz https://github.com/koalaman/shellcheck/releases/download/v$(SHELLCHECK_VERSION)/shellcheck-v$(SHELLCHECK_VERSION).linux.x86_64.tar.xz && \
		tar -xJf /tmp/shellcheck.tar.xz -C /tmp && \
		install -m 755 /tmp/shellcheck-v$(SHELLCHECK_VERSION)/shellcheck $$HOME/.local/bin/shellcheck && \
		rm -rf /tmp/shellcheck-v$(SHELLCHECK_VERSION) /tmp/shellcheck.tar.xz; \
	}

#deps-act: @ Install act for running GitHub Actions locally
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b $$HOME/.local/bin v$(ACT_VERSION); \
	}

#deps-trivy: @ Install trivy for local vulnerability scanning
deps-trivy:
	@command -v trivy >/dev/null 2>&1 || { echo "Installing trivy $(TRIVY_VERSION)..."; \
		mkdir -p $$HOME/.local/bin; \
		curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $$HOME/.local/bin v$(TRIVY_VERSION); \
	}

#api-docs: @ Build source code for swagger api reference
api-docs: deps
	@$(call go-exec,swag init --parseDependency -g main.go)

#test: @ Run tests
test: deps
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -v ./...)

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
		$(call go-exec,benchstat $$OLD_FILE $$NEW_FILE); \
	else \
		$(call go-exec,benchstat $(OLD) $(NEW)); \
	fi

#lint: @ Run golangci-lint and hadolint (comprehensive linting via .golangci.yml)
lint: deps deps-hadolint
	@$(call go-exec,golangci-lint run ./...)
	@hadolint Dockerfile

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
lint-ci: deps deps-shellcheck
	@$(call go-exec,actionlint)

#format: @ Format Go code
format: deps
	@$(call go-exec,gofmt -l -w .)

#static-check: @ Run code static check
static-check: lint-ci lint sec vulncheck secrets trivy-fs mermaid-lint
	@echo "Static check passed."

#build: @ Build REST API server's binary
build: deps api-docs
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) && go build -a -o server main.go)

#run: @ Run REST API locally
run: deps build
	@export TZ="UTC"; ./server -env-file .env

#image-build: @ Build Docker image (full checks + test)
image-build: static-check test build
	@./scripts/build-image.sh

#release: @ Create and push a new tag
release: ci
	@$(eval NT=$(NEWTAG))
	@echo "$(NT)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: Tag must match vN.N.N"; exit 1; }
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./pkg/api/version.txt
	@git add pkg/api/version.txt
	@git commit -s -m "Cut ${NT} release"
	@git tag ${NT}
	@git push origin ${NT}
	@git push
	@echo "Done."

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

#coverage: @ Run tests with coverage report
coverage: deps
	@mkdir -p $(OUTDIR)
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -coverprofile=$(COVPROF) -covermode=atomic ./internal/...)
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

#ci: @ Run full CI pipeline locally
ci: deps format static-check test coverage-check build fuzz deps-prune-check
	@echo "Local CI pipeline passed."

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@docker container prune -f 2>/dev/null || true
	@if [ -f ~/.secrets ]; then . ~/.secrets; fi; \
	act push -W .github/workflows/ci.yml \
		--container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts \
		--var ACT=true \
		$${GITHUB_TOKEN:+-s GITHUB_TOKEN=$$GITHUB_TOKEN}

#check: @ Run pre-commit checklist (alias for ci)
check: ci
	@echo "All pre-commit checks passed."

#trivy-fs: @ Run Trivy filesystem vulnerability scan (requires trivy)
trivy-fs: deps-trivy
	@trivy fs \
		--scanners vuln,secret,misconfig \
		--severity CRITICAL,HIGH \
		--skip-dirs test/node_modules,.pnpm-store \
		--exit-code 1 .

#trivy-image: @ Run Trivy image vulnerability scan (requires trivy)
trivy-image: deps-trivy
	@trivy image --severity CRITICAL,HIGH --exit-code 1 $(APP_NAME):scan

#docker-build: @ Build Docker image for local testing
docker-build: deps build
	@docker buildx build --load \
		--build-arg GOMODCACHE=$$($(call go-exec,go env GOMODCACHE)) \
		--build-arg GOCACHE=$$($(call go-exec,go env GOCACHE)) \
		-t $(APP_NAME):local .

#docker-run: @ Run Docker container locally
docker-run: docker-build
	@docker run --rm -p 8080:8080 -e SERVER_PORT=8080 \
		--entrypoint sh $(APP_NAME):local -c "touch /tmp/.env && /main -env-file /tmp/.env"

#docker-smoke-test: @ Smoke-test a pre-built Docker container (no rebuild)
docker-smoke-test:
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

#docker-test: @ Build and smoke-test Docker container
docker-test: docker-build
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

#docker-scan: @ Build Docker image and run Trivy scan (requires trivy)
docker-scan: deps-trivy build
	@docker buildx build --load \
		--build-arg GOMODCACHE=/go/pkg/mod \
		--build-arg GOCACHE=/root/.cache/go-build \
		-t $(APP_NAME):scan .
	@trivy image --severity CRITICAL,HIGH --exit-code 1 $(APP_NAME):scan

#e2e: @ Run Postman/Newman end-to-end tests
e2e: deps
	@curl -sf http://localhost:8080/ >/dev/null 2>&1 || { echo "Error: Server not running on port 8080. Start with 'make run &' first."; exit 1; }
	@./test/node_modules/.bin/newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json

#renovate-validate: @ Validate Renovate configuration
renovate-validate: deps
	@pnpm dlx renovate --platform=local

#mermaid-lint: @ Validate Mermaid diagrams in markdown files
mermaid-lint:
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required for mermaid-lint"; exit 1; }
	@set -eu; \
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

#deps-prune: @ Remove unused Go module dependencies
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

.PHONY: help deps deps-check deps-hadolint deps-shellcheck deps-act deps-trivy api-docs test fuzz bench bench-save bench-compare \
	lint vulncheck secrets sec lint-ci format static-check mermaid-lint build run image-build release update open-swagger \
	test-case-one test-case-two test-case-three e2e clean coverage coverage-check \
	ci ci-run check trivy-fs trivy-image docker-build docker-run docker-smoke-test docker-test docker-scan \
	renovate-validate deps-prune deps-prune-check
