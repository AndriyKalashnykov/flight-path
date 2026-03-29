.DEFAULT_GOAL := help

CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (current tag - ${CURRENTTAG}): " newtag; echo $$newtag')
GOFLAGS ?= -mod=mod
NEWMANTESTSLOCATION=./test/

HOMEDIR := $(CURDIR)
OUTDIR  := $(HOMEDIR)/output
COVPROF := $(HOMEDIR)/covprof.out  # coverage profile
GOOS ?= linux
GOARCH ?= amd64

# === Tool Versions (pinned) ===
SWAG_VERSION        := 1.16.6
GOSEC_VERSION       := 2.24.0
BENCHSTAT_VERSION   := 0.0.0-20260312031701-16a31bc5fbd0
GOLANGCI_VERSION    := 2.11.1
GOVULNCHECK_VERSION := 1.1.4
GITLEAKS_VERSION    := 8.24.0
ACTIONLINT_VERSION  := 1.7.7
NVM_VERSION         := 0.40.4
HADOLINT_VERSION    := 2.12.0
ACT_VERSION         := 0.2.86

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-16s\033[0m - %s\n", $$1, $$2}'

#deps: @ Download and install dependencies
deps:
	@command -v swag >/dev/null 2>&1 || { echo "Installing swag..."; go install github.com/swaggo/swag/cmd/swag@v$(SWAG_VERSION); }
	@command -v gosec >/dev/null 2>&1 || { echo "Installing gosec..."; go install github.com/securego/gosec/v2/cmd/gosec@v$(GOSEC_VERSION); }
	@command -v benchstat >/dev/null 2>&1 || { echo "Installing benchstat..."; go install golang.org/x/perf/cmd/benchstat@v$(BENCHSTAT_VERSION); }
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint..."; curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $$(go env GOPATH)/bin v$(GOLANGCI_VERSION); }
	@command -v govulncheck >/dev/null 2>&1 || { echo "Installing govulncheck..."; go install golang.org/x/vuln/cmd/govulncheck@v$(GOVULNCHECK_VERSION); }
	@command -v gitleaks >/dev/null 2>&1 || { echo "Installing gitleaks..."; go install github.com/zricethezav/gitleaks/v8@v$(GITLEAKS_VERSION); }
	@command -v actionlint >/dev/null 2>&1 || { echo "Installing actionlint..."; go install github.com/rhysd/actionlint/cmd/actionlint@v$(ACTIONLINT_VERSION); }
	@command -v node >/dev/null 2>&1 || { echo "Installing Node.js LTS via nvm..."; . "$${NVM_DIR:-$$HOME/.nvm}/nvm.sh" && nvm install --lts && nvm use --lts; }
	@[ -f test/node_modules/.bin/newman ] || { echo "Installing newman..."; cd test && npm install; }

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint /usr/local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

#deps-act: @ Install act for running GitHub Actions locally
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#api-docs: @ Build source code for swagger api reference
api-docs: deps
	@swag init --parseDependency -g main.go

#test: @ Run tests
test: deps
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go test -v ./...

#fuzz: @ Run fuzz tests for 30 seconds
fuzz: deps
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go test ./internal/handlers/ -fuzz=FuzzFindItinerary -fuzztime=30s

#bench: @ Run bench tests
bench: deps
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s

#bench-save: @ Save benchmark results to file
bench-save: deps
	@mkdir -p benchmarks
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s | tee benchmarks/bench_$(shell date +%Y%m%d_%H%M%S).txt

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
		benchstat $$OLD_FILE $$NEW_FILE; \
	else \
		benchstat $(OLD) $(NEW); \
	fi

#lint: @ Run golangci-lint and hadolint (60+ linters via .golangci.yml)
lint: deps deps-hadolint
	@golangci-lint run ./...
	@hadolint Dockerfile

#vulncheck: @ Run Go vulnerability check on dependencies
vulncheck: deps
	@govulncheck ./...

#secrets: @ Scan for hardcoded secrets in source code and git history
secrets: deps
	@gitleaks detect --source . --verbose --redact

#sec: @ Run gosec security scanner
sec: deps
	@gosec ./...

#lint-ci: @ Lint GitHub Actions workflow files
lint-ci: deps
	@actionlint

#static-check: @ Run code static check
static-check: deps lint sec vulncheck secrets lint-ci
	@echo "Static check done."

#build: @ Build REST API server's binary
build: api-docs
	@export GOFLAGS=$(GOFLAGS); export CGO_ENABLED=0; export GOOS=$(GOOS); export GOARCH=$(GOARCH); go build -a -o server main.go

#run: @ Run REST API locally
run: build
	@export TZ="UTC"; ./server -env-file .env

#image-build: @ Build Docker image - https://hub.docker.com/repository/docker/andriykalashnykov/flight-path/tags
image-build: static-check test api-docs
	@./scripts/build-image.sh

#release: @ Create and push a new tag
release: static-check test api-docs build
	$(eval NT=$(NEWTAG))
	@echo "$(NT)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "Error: Tag must match vN.N.N"; exit 1; }
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./pkg/api/version.txt
	@git add pkg/api/version.txt
	@git commit -a -s -m "Cut ${NT} release"
	@git tag ${NT}
	@git push origin ${NT}
	@git push
	@echo "Done."

#update: @ Update dependencies to latest versions
update:
	@export GOFLAGS=$(GOFLAGS); go get -u; go mod tidy

#open-swagger: @ Open browser with Swagger docs pointing to localhost
open-swagger:
	@command -v xdg-open >/dev/null && xdg-open http://localhost:8080/swagger/index.html 1>/dev/null 2>&1 || open http://localhost:8080/swagger/index.html 1>/dev/null 2>&1

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
	@go clean -testcache

#coverage: @ Run tests with coverage report
coverage: deps
	@mkdir -p $(OUTDIR)
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go test -coverprofile=$(COVPROF) -covermode=atomic ./internal/...
	@go tool cover -func=$(COVPROF)
	@go tool cover -html=$(COVPROF) -o $(OUTDIR)/coverage.html
	@echo "Coverage report: $(OUTDIR)/coverage.html"

#coverage-check: @ Verify coverage meets 80% threshold
coverage-check: coverage
	@TOTAL=$$(go tool cover -func=$(COVPROF) | grep total | awk '{print $$3}' | tr -d '%'); \
	echo "Coverage: $${TOTAL}%"; \
	if awk "BEGIN {exit !($${TOTAL} < 80)}"; then \
		echo "FAIL: Coverage $${TOTAL}% is below 80% threshold"; exit 1; \
	else \
		echo "PASS: Coverage meets 80% threshold"; \
	fi

#ci: @ Run full CI pipeline locally
ci: static-check build test fuzz
	@echo "Local CI pipeline passed."

#ci-full: @ Run full CI pipeline including coverage
ci-full: static-check build coverage-check fuzz
	@echo "Full CI pipeline passed."

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

#check: @ Run pre-commit checklist
check: static-check test api-docs build
	@echo "All pre-commit checks passed."

#trivy-fs: @ Run Trivy filesystem vulnerability scan
trivy-fs:
	@trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH --exit-code 1 .

#trivy-image: @ Run Trivy image vulnerability scan
trivy-image:
	@trivy image --severity CRITICAL,HIGH --exit-code 1 flight-path:scan

#docker-build: @ Build Docker image for local testing
docker-build:
	@docker buildx build --load \
		--build-arg GOMODCACHE=$$(go env GOMODCACHE) \
		--build-arg GOCACHE=$$(go env GOCACHE) \
		-t flight-path:local .

#docker-run: @ Run Docker container locally
docker-run: docker-build
	@docker run --rm -p 8080:8080 -e SERVER_PORT=8080 \
		--entrypoint sh flight-path:local -c "touch /tmp/.env && /main -env-file /tmp/.env"

#docker-test: @ Build and smoke-test Docker container
docker-test: docker-build
	@docker run -d --name fp-test -p 8080:8080 -e SERVER_PORT=8080 \
		--entrypoint sh flight-path:local -c "touch /tmp/.env && /main -env-file /tmp/.env"; \
	RESULT=0; \
	for i in $$(seq 1 10); do curl -sf http://localhost:8080/ >/dev/null 2>&1 && break; sleep 1; done; \
	curl -sf http://localhost:8080/ && echo "Health: OK" || { echo "Health: FAIL"; docker logs fp-test; RESULT=1; }; \
	curl -sf -X POST http://localhost:8080/calculate \
		-H 'Content-Type: application/json' \
		-d '[["SFO","ATL"],["ATL","EWR"]]' && echo "API: OK" || { echo "API: FAIL"; docker logs fp-test; RESULT=1; }; \
	docker rm -f fp-test 2>/dev/null || true; \
	exit $$RESULT

#e2e: @ Run Postman/Newman end-to-end tests
e2e: deps
	@curl -sf http://localhost:8080/ >/dev/null 2>&1 || { echo "Error: Server not running on port 8080. Start with 'make run &' first."; exit 1; }
	@NODE_NO_WARNINGS=1 ./test/node_modules/.bin/newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json

#renovate-bootstrap: @ Install nvm and npm for Renovate
renovate-bootstrap:
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@npx --yes renovate --platform=local

.PHONY: help deps deps-hadolint deps-act api-docs test fuzz bench bench-save bench-compare lint vulncheck secrets sec lint-ci static-check build run image-build release update open-swagger test-case-one test-case-two test-case-three e2e clean coverage coverage-check ci ci-full ci-run check trivy-fs trivy-image docker-build docker-run docker-test renovate-bootstrap renovate-validate
