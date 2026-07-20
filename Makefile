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
# the mise bootstrap version itself, the Node major-version mirror of .nvmrc,
# and the mermaid-cli Docker image.

# NODE_VERSION tracks major only — source of truth: .nvmrc (Renovate cannot track major-only values).
# Node is installed via mise (.mise.toml pins `node = "24"`); .nvmrc is kept for mise's native read.
NODE_VERSION        := $(shell cat .nvmrc 2>/dev/null || echo 24)
# pnpm is pinned in test/package.json via the `packageManager` field (corepack auto-switches).
# renovate: datasource=github-releases depName=jdx/mise
MISE_VERSION        := 2026.5.13
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION := 11.15.0
# PlantUML renderer for the C4 architecture diagrams (make diagrams). Renovate
# tracks the tag but it is EXCLUDED from automerge (see renovate.json "PlantUML
# renderer" rule): a renderer bump can change the committed PNG bytes, which
# `diagrams-check` correctly fails on, and the bot cannot run `make diagrams` to
# regenerate them — so a human regenerates per bump (runbook in CLAUDE.md).
# renovate: datasource=docker depName=plantuml/plantuml
PLANTUML_VERSION    := 1.2026.6
# Runner image `act` maps to the workflow's `runs-on: ubuntu-latest`. Pinned to
# a DATED, immutable catthehacker tag so `make ci-run` uses a controlled image
# that can't shift under an `act` upgrade. Renovate tracks it via the comment.
# renovate: datasource=docker depName=catthehacker/ubuntu versioning=loose
ACT_UBUNTU_VERSION  := act-latest-20260601

# Ensure tools installed to ~/.local/bin (mise bootstrap lives here) AND mise's
# shim dir (hadolint, trivy, act, goreleaser, golangci-lint, gosec, gitleaks,
# actionlint, shellcheck, govulncheck) are on PATH for every recipe — needed
# inside the act runner container where neither path is preconfigured.
# Exported so every sub-shell the recipes spawn inherits it.
export PATH := $(HOME)/.local/bin:$(HOME)/.local/share/mise/shims:$(PATH)

# Ephemeral host-port allocator. Use $$($(PICK_PORT)) inside recipes to bind a
# free port chosen by the kernel — prevents collisions when two `make image-run`
# or `make image-smoke-test` invocations run side-by-side (sibling repos, parallel
# CI jobs, two checkouts). Falls back to a random high-range port if the script
# isn't executable.
PICK_PORT := $(shell test -x scripts/pick-port.sh && echo ./scripts/pick-port.sh || echo 'shuf -i 40000-59999 -n 1')

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

#deps-mise: @ Bootstrap mise + install every tool pinned in .mise.toml
# Internal helper used by deps and deps-image; the `mise install` step is
# the same in both, so factor it once.
deps-mise:
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

#deps: @ Download and install dependencies (full toolchain — Go, Node, every quality tool, Newman)
deps: deps-go
	@command -v node >/dev/null 2>&1 || { \
		echo "Error: Node.js not found. Install mise (https://mise.jdx.dev), then run 'mise install' — .mise.toml pins node=$(NODE_VERSION)."; \
		exit 1; \
	}
	@# pnpm version is pinned in test/package.json via the `packageManager` field
	@# (e.g., "pnpm@10.5.2"). corepack reads that field on first invocation and
	@# auto-installs the exact version; no separate PNPM_VERSION constant is
	@# needed in this Makefile. Renovate updates the field in test/package.json.
	@#
	@# --install-directory is LOAD-BEARING — do not "simplify" it away.
	@#
	@# MEASURED: jdx/mise-action v4.2.1 (upstream commit b107e20a, "fix: exclude
	@# PATH from environment export") stopped exporting mise env's PATH and now
	@# adds only ~/.local/share/mise/shims. On that version, bare `corepack
	@# enable` exits 0 yet leaves no pnpm on PATH, so the NEXT recipe line dies
	@# with `pnpm: command not found` (exit 127). CI was green for ~3 months on
	@# v4.2.0 and broke on the bump; see CI run 29673837398.
	@#
	@# NOT ESTABLISHED: exactly which directory corepack picks on the runner.
	@# Two container reproductions (symlink shim, exec-wrapper shim) both had
	@# corepack write next to its own invocation path, which would have been on
	@# PATH — i.e. neither reproduced the failure. The chain is unresolved.
	@#
	@# So the fix does not depend on knowing that: pinning the install directory
	@# to ~/.local/bin — which line 58 above unconditionally prepends to PATH for
	@# every recipe — removes the variable entirely. Correct under both v4.2.0
	@# and v4.2.1.
	@command -v pnpm >/dev/null 2>&1 || { \
		echo "Enabling pnpm via corepack (version read from test/package.json packageManager field)..."; \
		mkdir -p "$$HOME/.local/bin"; \
		corepack enable --install-directory "$$HOME/.local/bin"; \
	}
	@[ -f test/node_modules/.bin/newman ] || { echo "Installing newman..."; cd test && pnpm install; }

#deps-image: @ Lean dependency target for image-* targets (mise tools only — no Node/pnpm/Newman)
# The image targets do not exercise Newman or any Go test code, so skipping
# Node + pnpm + the test/ pnpm install knocks ~10s off `make image-test` from
# a clean checkout in CI. `deps-mise` provides container-structure-test,
# trivy, and goreleaser via .mise.toml.
deps-image: deps-mise

#deps-go: @ Lean dependency target for Go-only targets (mise tools only — no Node/pnpm/Newman)
# Everything that compiles, tests, lints, or scans Go needs the mise toolchain
# and nothing else. Keeping those targets off the full `deps` chain means a
# Newman/corepack provisioning failure can no longer redden `static-check` —
# which is exactly what happened on 2026-07-20, when a corepack breakage took
# down linting. Only `e2e`, `e2e-quick` and `renovate-validate` genuinely need
# Node; `check-deps-tier` enforces that allowlist.
deps-go: deps-mise

#deps-check: @ Show required Go version and tool status
deps-check:
	@echo "Go version required: $(GO_VERSION)"
	@if command -v mise >/dev/null 2>&1; then mise list 2>/dev/null || echo "mise: .mise.toml not trusted — run 'mise trust'"; else echo "mise not installed - install from https://mise.jdx.dev"; fi
	@echo "--- Tool status ---"
	@for tool in swag benchstat golangci-lint gosec govulncheck gitleaks actionlint shellcheck hadolint trivy act goreleaser container-structure-test node pnpm; do \
		printf "  %-16s " "$$tool:"; \
		command -v $$tool >/dev/null 2>&1 && echo "installed" || echo "NOT installed"; \
	done

#api-docs: @ Generate Swagger API documentation from Go annotations
api-docs: deps-go
	@$(call go-exec,swag init --parseDependency -g main.go)

#test: @ Run unit + handler tests
test: deps-go
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -v ./...)

#integration-test: @ Run integration tests (full HTTP stack via httptest, CORS/middleware/error paths)
integration-test: deps-go
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -tags=integration -v ./internal/app/...)

#fuzz: @ Run fuzz tests for 30 seconds
fuzz: deps-go
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test ./internal/handlers/ -fuzz=FuzzFindItinerary -fuzztime=30s)

#bench: @ Run benchmarks for 3 seconds
bench: deps-go
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s)

#bench-save: @ Save benchmark results to a timestamped file
bench-save: deps-go
	@mkdir -p benchmarks
	@# $$(date) evaluates at recipe-execution time; $(shell date) would evaluate
	@# at Make-parse time and stamp identical timestamps on consecutive runs
	@# inside a single `make` invocation. `set -o pipefail` ensures a failed
	@# benchmark run propagates exit status through `tee` instead of being
	@# masked as exit 0.
	@set -o pipefail; $(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s) | tee "benchmarks/bench_$$(date +%Y%m%d_%H%M%S).txt"

#bench-compare: @ Compare two benchmark runs (auto-discovers latest two, or pass OLD=/NEW=)
bench-compare: deps-go
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
lint: deps-go lint-scripts-exec
	@$(call go-exec,golangci-lint run ./...)
	@command -v hadolint >/dev/null 2>&1 || { echo "ERROR: hadolint not on PATH. Run 'make deps' (installs via .mise.toml)."; exit 1; }
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
vulncheck: deps-go
	@$(call go-exec,govulncheck ./...)

#secrets: @ Scan for hardcoded secrets in source code and git history
secrets: deps-go
	@$(call go-exec,gitleaks detect --source . --verbose --redact)

#sec: @ Run gosec security scanner
sec: deps-go
	@$(call go-exec,gosec ./...)

#lint-ci: @ Lint GitHub Actions workflow files
lint-ci: deps-go
	@$(call go-exec,actionlint)

#format: @ Format Go code (rewrites files in place; for dev use)
format: deps-go
	@$(call go-exec,gofmt -l -w .)

#format-check: @ Verify Go code is gofmt-clean (CI gate; non-mutating, exits non-zero on diff)
format-check: deps-go
	@DIFF=$$($(call go-exec,gofmt -l .)); \
	if [ -n "$$DIFF" ]; then \
		echo "ERROR: gofmt would rewrite the following files. Run 'make format'."; \
		echo "$$DIFF"; \
		exit 1; \
	fi

#release-check: @ Validate .goreleaser.yml syntax and config
release-check: deps-go
	@command -v goreleaser >/dev/null 2>&1 || { echo "ERROR: goreleaser not on PATH. Run 'make deps' (installs via .mise.toml)."; exit 1; }
	@goreleaser check

#check-go-alignment: @ Verify the Go version matches across go.mod and .mise.toml (drift guard)
# The Dockerfile pins `golang:1.26-alpine` (minor tag, no patch), so only
# go.mod and .mise.toml carry the full patch version — those two are checked.
# Wired as the first dep of static-check so a 1-line version typo fails in
# milliseconds, before the expensive lint/vuln/trivy steps.
check-go-alignment:
	@gomod=$$(grep -oP '^go \K[0-9]+\.[0-9]+\.[0-9]+' go.mod); \
	misetoml=$$(grep -oP '^go\s*=\s*"\K[0-9]+\.[0-9]+\.[0-9]+' .mise.toml); \
	if [ "$$gomod" != "$$misetoml" ]; then \
		echo "ERROR: Go version disagrees between files:"; \
		printf "  %-12s %s\n" go.mod "$$gomod" .mise.toml "$$misetoml"; \
		echo "  Fix: align go.mod and .mise.toml to the same patch version."; \
		exit 1; \
	fi

#check-docs-go-version: @ Verify docs reference the same Go patch version as go.mod (drift guard)
# Catches the recurring miss where a go.mod patch bump (e.g. 1.26.3 -> 1.26.4)
# lands but prose docs keep advertising the old version. Scoped to the go.mod
# minor series (e.g. 1.26.x) so it flags ONLY Go-version drift — never Echo,
# Alpine, or tool versions — and ignores minor-only mentions like "Go 1.26".
# Dated history under docs/plan and docs/research is excluded (append, don't
# rewrite). Wired into static-check next to check-go-alignment so a forgotten
# doc sweep fails CI in milliseconds instead of shipping stale.
check-docs-go-version:
	@want=$$(grep -oP '^go \K[0-9]+\.[0-9]+\.[0-9]+' go.mod); \
	minor=$${want%.*}; \
	minore=$$(printf '%s' "$$minor" | sed 's/\./\\./g'); \
	bad=$$(git ls-files '*.md' ':(exclude)docs/plan/**' ':(exclude)docs/research/**' \
	      | xargs grep -nE "$$minore\.[0-9]+" 2>/dev/null \
	      | grep -vF "$$want" || true); \
	if [ -n "$$bad" ]; then \
		echo "ERROR: docs reference a Go $$minor.x version != go.mod ($$want):"; \
		echo "$$bad"; \
		echo "  Fix: update every live-state doc to $$want, then re-run."; \
		echo "  See the 'Bumping the Go version' checklist in the workflows skill."; \
		exit 1; \
	fi

#static-check: @ Run code static check
#check-deps-tier: @ Verify only e2e/e2e-quick/renovate-validate depend on the full (Node-provisioning) deps
# Keyed on an ALLOWLIST of the 3 targets that genuinely need Node, derived from
# the Makefile source itself — NOT on scanning `make -n static-check` output for
# node tokens. That token approach was measured and rejected: static-check's
# closure covers only 7 of the 24 repointed targets, so it was blind to a
# regression in the other 17 — including `ci`, `test`, `build` and `coverage`,
# the highest-traffic targets in the repo. This form catches all 24.
#
# Deliberately NOT scanning for a `pnpm` token either: trivy-fs (a static-check
# prereq) legitimately contains `--skip-dirs test/node_modules,.pnpm-store`, so
# a pnpm scan is RED on a correctly-fixed tree and would be deleted on day one.
check-deps-tier:
	@allow='e2e|e2e-quick|renovate-validate'; \
	pat='^[a-z][a-z0-9-]*:[^=]*[[:space:]]deps([[:space:]]|$$)'; \
	n=$$(grep -cE "$$pat" Makefile); \
	if [ "$$n" -lt 3 ]; then \
		echo "ERROR: check-deps-tier is VACUOUS — expected >=3 targets on the full 'deps', found $$n."; \
		echo "  The deps targets were probably renamed/restructured; this gate is no longer measuring anything."; \
		exit 1; \
	fi; \
	viol=$$(grep -nE "$$pat" Makefile | grep -vE "^[0-9]+:($$allow):" || true); \
	if [ -n "$$viol" ]; then \
		echo "ERROR: these targets depend on the full 'deps' (which provisions Node/pnpm/Newman)"; \
		echo "       but are not in the allowlist ($$allow):"; \
		echo "$$viol" | sed 's/^/  /'; \
		echo "  Fix: depend on 'deps-go' instead — a Go-only target must not be able to fail"; \
		echo "       because Newman provisioning broke. If it genuinely needs Node, add it to"; \
		echo "       the allowlist above with a reason."; \
		exit 1; \
	fi; \
	echo "check-deps-tier: OK — checked $$n targets on full deps, all allowlisted."

static-check: check-go-alignment check-docs-go-version check-deps-tier format-check lint-ci lint sec vulncheck secrets trivy-fs mermaid-lint diagrams-check release-check
	@echo "Static check passed."

#build: @ Build REST API server's binary
build: deps-go api-docs
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) && go build -a -o server main.go)

#run: @ Run REST API locally
run: deps-go build
	@export TZ="UTC"; ./server -env-file .env

#require-docker: @ Verify docker CLI is available (internal guard for image-* recipes)
require-docker:
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required for image-* targets"; exit 1; }

#image-build: @ Build Docker image for local testing
image-build: require-docker build
	@docker buildx build --load \
		--build-arg GOMODCACHE=$$($(call go-exec,go env GOMODCACHE)) \
		--build-arg GOCACHE=$$($(call go-exec,go env GOCACHE)) \
		-t $(APP_NAME):local .

#image-run: @ Run Docker container locally (detached on an ephemeral host port; use `image-stop` to tear down)
# Allocates an ephemeral host port so two parallel `make image-run` invocations
# don't collide. Container's internal port stays 8080. SERVER_PORT comes from
# .env.example via docker --env-file (host-side injection — the binary sees it
# as an OS env var, no .env file needed inside the container).
image-run: require-docker image-stop
	@PORT=$$($(PICK_PORT)); \
	CONTAINER_PORT=$$(awk -F= '/^SERVER_PORT=/{print $$2; exit}' .env.example); \
	docker run --rm -d --name $(APP_NAME) -p $$PORT:$$CONTAINER_PORT \
		--env-file .env.example \
		$(APP_NAME):local; \
	echo "Container $(APP_NAME) listening on http://$(LOCAL_HOST):$$PORT"

#image-stop: @ Stop the locally running Docker container
image-stop: require-docker
	@docker stop $(APP_NAME) 2>/dev/null || true
	@docker rm -f $(APP_NAME) 2>/dev/null || true

#image-push: @ Push Docker image to GHCR (requires GH_ACCESS_TOKEN and GHCR_USER)
image-push: require-docker image-build
	@if [ -z "$$GH_ACCESS_TOKEN" ]; then echo "Error: GH_ACCESS_TOKEN not set"; exit 1; fi
	@if [ -z "$(GHCR_USER)" ]; then echo "Error: GHCR_USER not set and git user.name unavailable"; exit 1; fi
	@echo "$$GH_ACCESS_TOKEN" | docker login ghcr.io -u "$(GHCR_USER)" --password-stdin
	@docker tag $(APP_NAME):local ghcr.io/$(GHCR_REPO):$(CURRENTTAG)
	@docker push ghcr.io/$(GHCR_REPO):$(CURRENTTAG)

#image-smoke-test: @ Smoke-test a pre-built Docker container (no rebuild)
# Uses an ephemeral host port + .env.example for config injection. Cleans up
# the test container on exit (success, failure, or interrupt) via trap.
image-smoke-test: require-docker
	@PORT=$$($(PICK_PORT)); \
	CONTAINER_PORT=$$(awk -F= '/^SERVER_PORT=/{print $$2; exit}' .env.example); \
	BASE="http://$(LOCAL_HOST):$$PORT"; \
	trap 'docker rm -f fp-test >/dev/null 2>&1 || true' EXIT INT TERM; \
	docker run -d --name fp-test -p $$PORT:$$CONTAINER_PORT \
		--env-file .env.example \
		$(APP_NAME):local >/dev/null; \
	RESULT=0; \
	for i in $$(seq 1 10); do curl -sf "$$BASE/" >/dev/null 2>&1 && break; sleep 1; done; \
	curl -sf "$$BASE/" >/dev/null && echo "Health: OK" || { echo "Health: FAIL"; docker logs fp-test; RESULT=1; }; \
	curl -sf -X POST "$$BASE/calculate" \
		-H 'Content-Type: application/json' \
		-d '[["SFO","ATL"],["ATL","EWR"]]' >/dev/null && echo "API: OK" || { echo "API: FAIL"; docker logs fp-test; RESULT=1; }; \
	exit $$RESULT

#image-structure-test: @ Validate Dockerfile metadata + binary properties (container-structure-test)
image-structure-test: require-docker deps-image
	@$(call go-exec,container-structure-test test --image $(APP_NAME):local --config container-structure-test.yaml)

#image-test: @ Build, smoke-test, and structure-test Docker container
image-test: image-build image-smoke-test image-structure-test

#image-scan: @ Build Docker image and run Trivy scan (requires trivy)
image-scan: require-docker deps-image build
	@docker buildx build --load \
		--build-arg GOMODCACHE=/go/pkg/mod \
		--build-arg GOCACHE=/root/.cache/go-build \
		-t $(APP_NAME):scan .
	@trivy image --severity CRITICAL,HIGH --exit-code 1 $(APP_NAME):scan

#release: @ Run full CI pipeline then tag and push a new release
release: ci
	@git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 || { \
		echo "Error: current branch has no upstream. Set one with 'git push -u origin $$(git symbolic-ref --short HEAD)' before releasing."; \
		exit 1; \
	}
	@NT=$$(bash -c 'read -p "Please provide a new tag (current tag - $(CURRENTTAG)): " newtag; echo $$newtag'); \
	echo "$$NT" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: Tag must match vN.N.N"; exit 1; }; \
	if git rev-parse -q --verify "refs/tags/$$NT" >/dev/null 2>&1; then echo "ERROR: tag $$NT already exists locally. Pick a new version or delete it: git tag -d $$NT"; exit 1; fi; \
	if git ls-remote --exit-code --tags origin "refs/tags/$$NT" >/dev/null 2>&1; then echo "ERROR: tag $$NT already exists on origin. Pick a new version."; exit 1; fi; \
	read -p "Are you sure to create and push $$NT tag? [y/N] " ans; [ "$${ans:-N}" = y ] || exit 1; \
	echo "$$NT" > ./pkg/api/version.txt; \
	git add pkg/api/version.txt; \
	git commit -s -m "Cut $$NT release"; \
	git tag "$$NT"; \
	git push origin "$$NT"; \
	git push; \
	echo "Done."

#update: @ Update Go dependencies to latest versions and run `go mod tidy`
update: deps-go
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) && go get -u ./... && go mod tidy)

# === Platform Detection ===
OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

# Host + port for dev-convenience curl/open targets — both env-overridable so
# overrides set in .env (or exported in the shell) flow through. Default host
# is localhost (single-machine dev), default port is 8080 (matches .env).
LOCAL_HOST ?= $(or $(SERVER_HOST),localhost)
LOCAL_PORT ?= $(or $(SERVER_PORT),8080)
LOCAL_BASE := http://$(LOCAL_HOST):$(LOCAL_PORT)

#open-swagger: @ Open browser with Swagger docs pointing to localhost
open-swagger:
	@$(OPEN_CMD) $(LOCAL_BASE)/swagger/index.html 1>/dev/null 2>&1

#test-case-one: @ Test case #1 [["SFO", "EWR"]]
test-case-one:
	@curl -X 'POST' \
	      '$(LOCAL_BASE)/calculate' \
	      -H 'accept: application/json' \
	      -H 'Content-Type: application/json' \
	      -d '[["SFO", "EWR"]]'

#test-case-two: @ Test case #2 [["ATL", "EWR"], ["SFO", "ATL"]]
test-case-two:
	@curl -X 'POST' \
	      '$(LOCAL_BASE)/calculate' \
	      -H 'accept: application/json' \
	      -H 'Content-Type: application/json' \
	      -d '[["ATL", "EWR"], ["SFO", "ATL"]]'

#test-case-three: @ Test case #3 [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
test-case-three:
	@curl -X 'POST' \
	      '$(LOCAL_BASE)/calculate' \
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
coverage: deps-go
	@mkdir -p $(OUTDIR)
	@$(call go-exec,export GOFLAGS=$(GOFLAGS) TZ="UTC" && go test -race -tags=integration -coverpkg=./internal/... -coverprofile=$(COVPROF) -covermode=atomic ./internal/...)
	@$(call go-exec,go tool cover -func=$(COVPROF))
	@$(call go-exec,go tool cover -html=$(COVPROF) -o $(OUTDIR)/coverage.html)
	@echo "Coverage report: $(OUTDIR)/coverage.html"

#coverage-check: @ Verify the coverage profile meets the 80% threshold (run `make coverage` first)
coverage-check: deps-go
	@if [ ! -s $(COVPROF) ]; then \
		echo "ERROR: $(COVPROF) missing or empty. Run 'make coverage' first."; \
		exit 1; \
	fi
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
# Note: `coverage` runs the integration-tagged test suite to produce the
# profile that `coverage-check` then asserts against; running it after `test`
# and `integration-test` ensures `coverage-check` operates on a fresh profile
# without re-running every assertion a third time.
ci: deps-go static-check test integration-test coverage coverage-check build fuzz deps-prune-check
	@echo "Local CI pipeline passed."

#ci-run: @ Run GitHub Actions workflow locally using act
# Synthetic push-event payload (--eventpath) gives dorny/paths-filter the
# repository.default_branch field act omits by default — without it, the
# `changes` detector job errors and every downstream gated job is blocked.
# The all-zero before/after SHAs make dorny treat the push as the initial
# commit and report every file as changed, so `code=true` and every job
# runs — desired behavior for local CI (opposite of the doc-only-skip
# behavior on GitHub).
ci-run: deps-go
	@docker container prune -f 2>/dev/null || true
	@EVENT=$$(mktemp /tmp/act-push-event.XXXXXX.json); \
	printf '{"repository":{"default_branch":"main"},"ref":"refs/heads/main","before":"0000000000000000000000000000000000000000","after":"0000000000000000000000000000000000000000"}' > $$EVENT; \
	: '~/.secrets is an optional dotenv-style file (e.g., GITHUB_TOKEN=ghp_...) that'; \
	: 'is sourced into the recipe shell so secret_args below can pass --secret KEY'; \
	: '(env-only form) to act. Never put secret VALUES on the act command line.'; \
	if [ -f ~/.secrets ]; then . ~/.secrets; fi; \
	ACT_PORT=$$(shuf -i 40000-59999 -n 1); \
	ARTIFACT_PATH=$$(mktemp -d -t act-artifacts.XXXXXX); \
	secret_args=(); \
	if [ -n "$$GITHUB_TOKEN" ]; then secret_args+=(--secret GITHUB_TOKEN); fi; \
	RC=0; \
	: 'Skipped under act: dast (needs Docker-in-Docker for OWASP ZAP),'; \
	: 'goreleaser (tag-only, runs in real GHA on v* push). Both are exercised'; \
	: 'in real CI; the local loop covers every job that can complete under act.'; \
	for job in static-check build test integration-test e2e docker; do \
		echo "=== act job: $$job ==="; \
		act push -W .github/workflows/ci.yml \
			--job $$job \
			--eventpath $$EVENT \
			-P ubuntu-latest=catthehacker/ubuntu:$(ACT_UBUNTU_VERSION) \
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
trivy-fs: deps-image
	@command -v trivy >/dev/null 2>&1 || { echo "ERROR: trivy not on PATH. Run 'make deps' (installs via .mise.toml)."; exit 1; }
	@trivy fs \
		--scanners vuln,secret,misconfig \
		--severity CRITICAL,HIGH \
		--skip-dirs test/node_modules,.pnpm-store \
		--exit-code 1 .

#trivy-image: @ Run Trivy image vulnerability scan
trivy-image: deps-image
	@command -v trivy >/dev/null 2>&1 || { echo "ERROR: trivy not on PATH. Run 'make deps' (installs via .mise.toml)."; exit 1; }
	@trivy image --severity CRITICAL,HIGH --exit-code 1 $(APP_NAME):scan

#e2e: @ Build + start server + run e2e + stop server (self-contained; called by `make ci`)
# Allocates an ephemeral port via scripts/pick-port.sh so parallel runs
# (two checkouts, sibling repos under a single dev machine, multi-job CI)
# don't collide on a fixed 8080. Newman gets baseUrl via --env-var. The trap
# guarantees the server process and PID file are cleaned up even if the
# wait-for-server poll fails before Newman starts (without trap, a backgrounded
# server would leak past recipe failure).
e2e: deps build
	@PORT=$$(./scripts/pick-port.sh); \
		BASE="http://$(LOCAL_HOST):$$PORT"; \
		PIDFILE=$$(mktemp -t flight-path-e2e.XXXXXX.pid); \
		cleanup() { \
			[ -f "$$PIDFILE" ] && kill "$$(cat "$$PIDFILE")" 2>/dev/null || true; \
			rm -f "$$PIDFILE"; \
		}; \
		trap cleanup EXIT INT TERM; \
		SERVER_PORT=$$PORT ./server -env-file .env >/tmp/flight-path-e2e.log 2>&1 & echo $$! > "$$PIDFILE"; \
		./scripts/wait-for-server.sh "$$BASE/" 30; \
		EXIT=0; \
		./test/node_modules/.bin/newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json \
			--env-var "baseUrl=$$BASE" || EXIT=$$?; \
		exit $$EXIT

#e2e-quick: @ Run Postman/Newman end-to-end tests (requires server already running)
e2e-quick: deps
	@BASE="$(LOCAL_BASE)"; \
		curl -sf "$$BASE/" >/dev/null 2>&1 || { echo "Error: Server not running on $$BASE. Start with 'make run &' first (or override LOCAL_HOST/LOCAL_PORT for a remote host)."; exit 1; }; \
		./test/node_modules/.bin/newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json \
			--env-var "baseUrl=$$BASE"

#renovate-validate: @ Validate Renovate configuration
renovate-validate: deps
	@# Use `npx` (corepack-installed alongside Node) rather than `pnpm dlx`.
	@# Renovate currently declares `engines.pnpm: ^10.0.0`; corepack here ships
	@# pnpm 11, so `pnpm dlx renovate` aborts with ERR_PNPM_UNSUPPORTED_ENGINE.
	@# `npx` resolves the tarball directly, side-stepping the engine gate.
	@# `renovate@latest` (not bare `renovate`): npx caches the resolved binary
	@# indefinitely, so a stale cache can reject current config schema (e.g.
	@# `managerFilePatterns`). `@latest` forces a fresh dist-tag resolve.
	@# GITHUB_COM_TOKEN (env-renamed from GH_ACCESS_TOKEN via `export`, never
	@# argv) gives Renovate authenticated API calls — avoids the rate-limit
	@# warning on changelog/version lookups.
	@if [ -n "$$GH_ACCESS_TOKEN" ]; then \
		export GITHUB_COM_TOKEN="$$GH_ACCESS_TOKEN"; \
	else \
		echo "Warning: GH_ACCESS_TOKEN not set — Renovate API lookups may hit rate limits"; \
	fi; \
		npx --yes renovate@latest --platform=local

# === C4 architecture diagrams (PlantUML) ===
# Source .puml + rendered PNG are BOTH committed so github.com shows the images
# without a toolchain. `diagrams-check` (wired into static-check) fails if a
# .puml edit OR a PLANTUML_VERSION bump isn't accompanied by a re-render.
DIAGRAM_DIR   := docs/diagrams
DIAGRAM_SRC   := $(wildcard $(DIAGRAM_DIR)/*.puml)
DIAGRAM_OUT   := $(patsubst $(DIAGRAM_DIR)/%.puml,$(DIAGRAM_DIR)/out/%.png,$(DIAGRAM_SRC))
# Version-stamped sentinel: its NAME encodes PLANTUML_VERSION, so a renderer
# bump invalidates the prereq and forces a full re-render (catches the
# "renderer bumped but PNGs left stale" green-on-stale class). Gitignored.
DIAGRAM_STAMP := $(DIAGRAM_DIR)/out/.plantuml-$(PLANTUML_VERSION).stamp

#diagrams: @ Render C4 PlantUML architecture diagrams to PNG
diagrams: $(DIAGRAM_OUT)

$(DIAGRAM_DIR)/out/%.png: $(DIAGRAM_DIR)/%.puml $(DIAGRAM_STAMP)
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required for diagrams"; exit 1; }
	@mkdir -p $(DIAGRAM_DIR)/out
	docker run --rm -v "$(CURDIR)/$(DIAGRAM_DIR):/work" -w /work \
		--user $$(id -u):$$(id -g) \
		-e HOME=/tmp -e _JAVA_OPTIONS=-Duser.home=/tmp \
		plantuml/plantuml:$(PLANTUML_VERSION) \
		-tpng -o out $(notdir $<)

$(DIAGRAM_STAMP):
	@mkdir -p $(DIAGRAM_DIR)/out
	@rm -f $(DIAGRAM_DIR)/out/.plantuml-*.stamp
	@touch $@

#diagrams-clean: @ Remove rendered diagram artefacts (forces full re-render)
diagrams-clean:
	rm -rf $(DIAGRAM_DIR)/out

#diagrams-check: @ Verify committed diagrams match current source + renderer (CI)
diagrams-check: diagrams
	@git diff --exit-code -- $(DIAGRAM_DIR)/out || \
		{ echo "ERROR: Diagram source or PLANTUML_VERSION changed but rendered PNGs not updated. Run 'make diagrams' and commit."; exit 1; }

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
deps-prune: deps-go
	@echo "=== Dependency Pruning ==="
	@echo "--- Go: running go mod tidy ---"
	@$(call go-exec,go mod tidy)
	@echo "=== Pruning complete ==="

#deps-prune-check: @ Verify no prunable dependencies (CI gate)
deps-prune-check: deps-go
	@$(call go-exec,go mod tidy)
	@if ! git diff --exit-code go.mod go.sum >/dev/null 2>&1; then \
		echo "ERROR: go.mod/go.sum not tidy. Run 'make deps-prune'."; \
		git checkout go.mod go.sum; \
		exit 1; \
	fi
	@echo "No prunable dependencies found."

.PHONY: help deps deps-mise deps-image deps-go deps-check check-deps-tier api-docs test integration-test fuzz bench bench-save bench-compare \
	lint lint-scripts-exec vulncheck secrets sec lint-ci format format-check check-go-alignment check-docs-go-version static-check mermaid-lint diagrams diagrams-clean diagrams-check release-check build run release update open-swagger \
	test-case-one test-case-two test-case-three e2e e2e-quick clean coverage coverage-check \
	ci ci-run check trivy-fs trivy-image \
	require-docker image-build image-run image-stop image-push image-smoke-test image-structure-test image-test image-scan \
	renovate-validate deps-prune deps-prune-check
