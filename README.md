[![ci](https://github.com/AndriyKalashnykov/flight-path/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AndriyKalashnykov/flight-path/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/flight-path.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/flight-path/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/flight-path)
# REST API server to determine the flight path of a person

Story: There are over 100,000 flights a day, with millions of people and cargo being transferred around the world.
With so many people and different carrier/agency groups, it can be hard to track where a person might be.
In order to determine the flight path of a person, we must sort through all of their flight records.

Goal: To create a simple microservice API that can help us understand and track how a particular person's flight path
may be queried. The API should accept a request that includes a list of flights, which are defined by a source and
destination airport code. These flights may not be listed in order and will need to be sorted to find the total
flight paths starting and ending airports.

### Requirements

- [gvm](https://github.com/moovweb/gvm) Go
    ```bash
    gvm install go1.26.0 --prefer-binary --with-build-tools --with-protobuf
    gvm use go1.26.0 --default
    ```
  - [nmv](https://github.com/nvm-sh/nvm) Node
  ```bash
    nvm install --lts
    nvm use --lts
    npm install yarn --global
    npm install npm --global
    npm install -g pnpm
    pnpm add -g pnpm
  ```
- All dev tools are installed automatically:
  ```bash
  make deps
  ```

## Help

```text
Usage: make COMMAND
Commands :
help            - List available tasks
deps            - Download and install dependencies
api-docs        - Build source code for swagger api reference
lint            - Run golangci-lint (60+ linters via .golangci.yml)
sec             - Run gosec security scanner
vulncheck       - Run Go vulnerability check on dependencies
secrets         - Scan for hardcoded secrets in source code and git history
lint-ci         - Lint GitHub Actions workflow files
test            - Run tests
bench           - Run bench tests
bench-save      - Save benchmark results to file
bench-compare   - Compare two benchmark files
fuzz            - Run fuzz tests for 30 seconds
build           - Build REST API server's binary
run             - Run REST API locally
build-image     - Build Docker image
release         - Create and push a new tag
update          - Update dependencies to latest versions
open-swagger    - Open browser with Swagger docs pointing to localhost
test-case-one   - Test case 1 [["SFO", "EWR"]]
test-case-two   - Test case 2 [["ATL", "EWR"], ["SFO", "ATL"]]
test-case-three - Test case 3 [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
e2e             - Run Postman/Newman end-to-end tests
```

## Start REST API server

```bash
make run
```

## Run test cases

```bash
make test-case-one
make test-case-two
make test-case-three
```

## Security & Code Quality

### SAST (Static Application Security Testing)

| Tool | Command | What it does |
|------|---------|-------------|
| [gosec](https://github.com/securego/gosec) | `make sec` | Go-specific security scanner (injection, crypto, permissions) |
| [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) | `make vulncheck` | Checks dependencies against the Go vulnerability database |
| [gitleaks](https://github.com/gitleaks/gitleaks) | `make secrets` | Scans source code and git history for hardcoded secrets |

### DAST (Dynamic Application Security Testing)

| Tool | Where | What it does |
|------|-------|-------------|
| [OWASP ZAP](https://github.com/zaproxy/zaproxy) | CI only | API security scan using Swagger/OpenAPI spec |

### Linting

| Tool | Command | What it does |
|------|---------|-------------|
| [golangci-lint](https://github.com/golangci/golangci-lint) | `make lint` | Meta-linter running 60+ linters (configured via `.golangci.yml`) |
| [actionlint](https://github.com/rhysd/actionlint) | `make lint-ci` | Lints GitHub Actions workflow files |

### Container Security

| Tool | Where | What it does |
|------|-------|-------------|
| [Trivy](https://github.com/aquasecurity/trivy) | CI only | Scans Docker images and filesystem for CVEs |

### Testing

| Tool | Command | What it does |
|------|---------|-------------|
| go test | `make test` | Unit and handler tests (table-driven) |
| go test -bench | `make bench` | Benchmark tests for critical paths |
| go test -fuzz | `make fuzz` | Fuzz testing for FindItinerary algorithm |
| [Newman](https://github.com/postmanlabs/newman) | `make e2e` | Postman/Newman end-to-end API tests |

### Pre-commit Checklist

```bash
make lint && make sec && make vulncheck && make secrets && make test && make api-docs && make build
```

## SwaggerUI

Take a look at autogenerated REST API Documentation

[Swagger API documentation - http://localhost:8080/swagger/index.html](http://localhost:8080/swagger/index.html)

![Swagger API documentation](./img/swagger-api-doc.jpg)


## API Endpoint documentation

[API Endpoint documentation](./docs/swagger.json)

```json
        "/calculate": {
            "post": {
                "description": "get the flight path of a person.",
                "consumes": [
                    "application/json"
                ],
                "produces": [
                    "application/json"
                ],
                "tags": [
                    "FlightCalculate"
                ],
                "summary": "Determine the flight path of a person.",
                "operationId": "flightCalculate-get",
                "parameters": [
                    {
                        "description": "Flight segments",
                        "name": "flightSegments",
                        "in": "body",
                        "required": true,
                        "schema": {
                            "type": "array",
                            "items": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    }
                ],
                "responses": {
                    "200": {
                        "description": "OK",
                        "schema": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            }
                        }
                    },
                    "500": {
                        "description": "Internal Server Error",
                        "schema": {
                            "type": "object",
                            "additionalProperties": true
                        }
                    }
                }
            }
        }
```

## GitHub CI

GitHub CI pipeline:

| Job | Steps |
|-----|-------|
| **static-check** | golangci-lint, gosec, govulncheck, gitleaks, actionlint, Trivy filesystem scan |
| **builds** | Build binary |
| **tests** | Unit + handler tests |
| **integration** | Build, run server, Newman/Postman E2E tests |
| **dast** | Build, run server, OWASP ZAP API security scan |
| **image-scan** | Build Docker image, Trivy vulnerability scan |

## Postman/Newman end-to-end tests

Utilized Postman collection exported to [JSON file](./test/FlightPath.postman_collection.json)
and executes same use cases as Makefile targets `test-case-one` `test-case-two` `test-case-three`, plus negative test cases (empty body, malformed JSON, incomplete segment)

![Postman/Newman end-to-end tests](./img/posman-newmanjpg.jpg)
