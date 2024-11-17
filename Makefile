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
	go install github.com/swaggo/swag/cmd/swag@latest
	go install -v github.com/golangci/golangci-lint/cmd/golangci-lint@latest

#api-docs: @ Build source code for swagger api reference
api-docs: deps
	swag init --parseDependency -g main.go

#lint: @ Run lint
lint:
	golangci-lint run  --fast ./...

#test: @ Run tests
test:
	@go generate
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go test -v

#build: @ Build REST API server's binary
build: api-docs
	@go generate
	@export GOFLAGS=$(GOFLAGS); export CGO_ENABLED=0; export GOOS=linux; export GOARCH=amd64; go build -a -o server main.go

#run: @ Run REST API locally
run: build api-docs
	@export GOFLAGS=$(GOFLAGS); export TZ="UTC"; go run main.go -env-file .env

#build-image: @ Build Docker image - https://hub.docker.com/repository/docker/andriykalashnykov/flight-path/tags
build-image: api-docs
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
e2e:
	newman run $(NEWMANTESTSLOCATION)FlightPath.postman_collection.json

critic:
	go install -v github.com/go-critic/go-critic/cmd/gocritic@latest
	gocritic check -enableAll ./...

sec:
	go install github.com/securego/gosec/v2/cmd/gosec@latest
	gosec ./...
