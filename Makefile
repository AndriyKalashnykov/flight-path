CURRENTTAG:=$(shell git describe --tags --abbrev=0)
NEWTAG ?= $(shell bash -c 'read -p "Please provide a new tag (currnet tag - ${CURRENTTAG}): " newtag; echo $$newtag')
GOFLAGS=-mod=mod
NEWMANTESTSLOCATION=./test/

HOMEDIR := $(shell pwd)
OUTDIR  := $(HOMEDIR)/output
COVPROF := $(HOMEDIR)/covprof.out  # coverage profile

#help: @ List available tasks
help:
	@clear
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-15s\033[0m - %s\n", $$1, $$2}'

#deps: @ Download and install dependencies
deps:
	@command -v swag >/dev/null 2>&1 || { echo "Installing swag..."; go install github.com/swaggo/swag/cmd/swag@latest; }
	@command -v gosec >/dev/null 2>&1 || { echo "Installing gosec..."; go install github.com/securego/gosec/v2/cmd/gosec@latest; }
	@command -v benchstat >/dev/null 2>&1 || { echo "Installing benchstat..."; go install golang.org/x/perf/cmd/benchstat@latest; }
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint..."; curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $$(go env GOPATH)/bin; }
	@command -v govulncheck >/dev/null 2>&1 || { echo "Installing govulncheck..."; go install golang.org/x/vuln/cmd/govulncheck@latest; }
	@command -v gitleaks >/dev/null 2>&1 || { echo "Installing gitleaks..."; go install github.com/zricethezav/gitleaks/v8@latest; }
	@command -v actionlint >/dev/null 2>&1 || { echo "Installing actionlint..."; go install github.com/rhysd/actionlint/cmd/actionlint@latest; }
	@command -v node >/dev/null 2>&1 || { echo "Installing Node.js LTS via nvm..."; . "$${NVM_DIR:-$$HOME/.nvm}/nvm.sh" && nvm install --lts && nvm use --lts; }
	@command -v newman >/dev/null 2>&1 || { echo "Installing newman..."; npm install --location=global newman; }

#api-docs: @ Build source code for swagger api reference
api-docs: deps
	swag init --parseDependency -g main.go

#lint: @ Run golangci-lint (60+ linters via .golangci.yml)
lint: deps
	golangci-lint run ./...

#test: @ Run tests
test:
	@go generate
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go test -v ./...

#bench: @ Run bench tests
bench:
	go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s

#bench-save: @ Save benchmark results to file
bench-save: deps
	@mkdir -p benchmarks
	@go test ./internal/handlers/ -bench=. -benchmem -benchtime=3s | tee benchmarks/bench_$(shell date +%Y%m%d_%H%M%S).txt

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

#vulncheck: @ Run Go vulnerability check on dependencies
vulncheck: deps
	govulncheck ./...

#secrets: @ Scan for hardcoded secrets in source code and git history
secrets: deps
	gitleaks detect --source . --verbose --redact

#lint-ci: @ Lint GitHub Actions workflow files
lint-ci: deps
	actionlint

#fuzz: @ Run fuzz tests for 30 seconds
fuzz:
	go test ./internal/handlers/ -fuzz=FuzzFindItinerary -fuzztime=30s

#build: @ Build REST API server's binary
build: deps lint sec vulncheck secrets api-docs
	@go generate
	@export GOFLAGS=$(GOFLAGS); export CGO_ENABLED=0; export GOOS=linux; export GOARCH=amd64; go build -a -o server main.go

#run: @ Run REST API locally
run: build api-docs
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go run main.go -env-file .env

#build-image: @ Build Docker image - https://hub.docker.com/repository/docker/andriykalashnykov/flight-path/tags
build-image: deps api-docs lint sec vulncheck secrets
	@./scripts/build-image.sh

#release: @ Create and push a new tag
release: api-docs build
	$(eval NT=$(NEWTAG))
	@echo -n "Are you sure to create and push ${NT} tag? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo ${NT} > ./pkg/api/version.txt
	@git add -A
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
	xdg-open http://localhost:8080/swagger/index.html 1>/dev/null 2>&1

#test-case-one: @ Test case #1 [["SFO", "EWR"]]
test-case-one:
	curl -X 'POST' \
      'http://localhost:8080/calculate' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '[["SFO", "EWR"]]'

#test-case-two: @ Test case #2 [["ATL", "EWR"], ["SFO", "ATL"]]
test-case-two:
	curl -X 'POST' \
      'http://localhost:8080/calculate' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '[["ATL", "EWR"], ["SFO", "ATL"]]'

#test-case-three: @ Test case #3 [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
test-case-three:
	curl -X 'POST' \
      'http://localhost:8080/calculate' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -d '[["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]'

#e2e: @ Run Postman/Newman end-to-end tests
e2e: deps
	newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json

#sec: @ Run gosec security scanner
sec: deps
	gosec ./...
