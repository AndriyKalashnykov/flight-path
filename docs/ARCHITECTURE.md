# Architecture

C4 Container, request-flow sequence, and CI/CD pipeline diagrams for the Flight Path API. The System Context diagram lives in the project [README](../README.md#overview).

## C4 Container Diagram

flight-path ships as **one runnable container** — a statically-linked Go binary
that embeds the HTTP server, routing, handlers, the `FindItinerary` algorithm,
and the Swagger UI (via `swaggo/echo-swagger`). It has no datastore, message
broker, cache, or third-party API dependency at runtime — the diagram below
shows the complete runtime topology.

```mermaid
C4Container
    title Container Diagram - Flight Path API

    Person(client, "API Client", "cURL, Postman, Newman, browser")

    System_Boundary(api, "Flight Path API") {
        Container(server, "flight-path server", "Go 1.26.2, Echo v5.1.0", "Single static binary. Serves POST /calculate, GET /, and GET /swagger/* (embedded Swagger UI via swaggo/echo-swagger v2.0.1). Middleware stack: Logger, Recover, CORS, Secure, Cache-Control, Gzip, RequestID, BodyLimit 1 MiB.")
    }

    Rel(client, server, "POST /calculate, GET /, GET /swagger/*", "HTTPS / JSON")
```

The internal package layout (`internal/{routes,handlers}`, `pkg/api/`) mirrors
the layered-architecture table in the [README Architecture section](../README.md#architecture)
— there is no Component-level surprise that warrants a separate C4 Component
diagram.

## Request Flow — POST /calculate

Sequence diagram showing how a flight path calculation request flows through the system.

```mermaid
sequenceDiagram
    autonumber
    participant C as API Client
    participant E as Echo Server
    participant MW as Middleware
    participant H as FlightCalculate Handler
    participant A as FindItinerary Algorithm

    C->>E: POST /calculate<br/>Body: [["SFO","ATL"],["ATL","EWR"]]
    E->>MW: Request passes through middleware
    MW-->>MW: Logger → Recover → CORS → Security Headers → Cache-Control
    MW->>H: Route matched → handler called

    H->>H: Bind JSON payload to [][]string
    alt Bind fails
        H-->>C: 400 {"Error": "Can't parse the payload"}
    end

    H->>H: Validate: segments non-empty, each has 2 airports
    alt Validation fails
        H-->>C: 400 {"Error": "...validation message..."}
    end

    H->>H: Convert [][]string → []Flight
    H->>A: FindItinerary(flights)

    A->>A: Pass 1: Build starts{} and ends{} maps
    A->>A: Pass 2: Find airport not in ends (start),<br/>find airport not in starts (end)
    A-->>H: return (start="SFO", end="EWR")

    H-->>C: 200 ["SFO", "EWR"]
```

## Request Flow — CORS preflight + security headers

Browser-initiated cross-origin requests issue an `OPTIONS` preflight before the
actual `POST`. The CORS middleware answers preflight; the Secure middleware
attaches headers (XCTO, XFO, CSP, HSTS, XSS-Protection, Referrer-Policy) and
Cache-Control / Cross-Origin-Resource-Policy on every response.

```mermaid
sequenceDiagram
    autonumber
    participant B as Browser
    participant E as Echo Server
    participant CORS as CORS Middleware
    participant SEC as Secure + Cache Middleware
    participant H as FlightCalculate Handler

    B->>E: OPTIONS /calculate<br/>Origin, Access-Control-Request-Method, -Headers
    E->>CORS: preflight
    CORS-->>B: 204 No Content<br/>Access-Control-Allow-Origin: * (or CORS_ORIGIN)<br/>Access-Control-Allow-Methods: GET, POST, OPTIONS

    B->>E: POST /calculate (real request)
    E->>CORS: pass through
    CORS->>SEC: pass through
    SEC->>H: handler invoked
    H-->>SEC: 200 ["SFO", "EWR"]
    SEC-->>B: 200 + security headers<br/>(XCTO, XFO, XSS-Protection, Referrer-Policy,<br/>Cache-Control, Cross-Origin-Resource-Policy)
```

## CI/CD Pipeline

The single workflow at [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every push, pull request, and `v*` tag. A `changes` paths-filter gates every heavy job on whether the push touches code; `ci-pass` is the single required status check for branch protection.

```mermaid
flowchart TD
    trigger["push / pull_request / tag v*"] --> changes["changes<br/>(dorny/paths-filter)"]

    changes -->|code = true| static["static-check<br/>(make static-check)"]
    changes -->|code = true| build["build<br/>(upload binary)"]

    static --> test["test<br/>(coverage 80% + fuzz)"]
    static --> integ["integration-test<br/>(httptest, //go:build integration)"]

    build --> e2e["e2e<br/>(Newman / Postman, 18 cases)"]
    test --> e2e
    build --> dast["dast<br/>(OWASP ZAP, skipped under act)"]
    test --> dast

    static --> docker
    build --> docker
    test --> docker

    docker["docker<br/>build → Trivy → smoke → multi-arch<br/>(push + cosign sign on tag)"]

    e2e --> goreleaser
    dast --> goreleaser
    integ --> goreleaser
    static --> goreleaser
    build --> goreleaser
    test --> goreleaser
    goreleaser["goreleaser<br/>(tag only)"] --> docker

    changes --> pass
    static --> pass
    build --> pass
    test --> pass
    integ --> pass
    e2e --> pass
    dast --> pass
    goreleaser --> pass
    docker --> pass
    pass["ci-pass<br/>(required status check)"]

    style changes fill:#fff3e0
    style static fill:#e1f5fe
    style test fill:#e8f5e9
    style integ fill:#e8f5e9
    style e2e fill:#e8f5e9
    style dast fill:#fce4ec
    style docker fill:#f3e5f5
    style goreleaser fill:#f3e5f5
    style pass fill:#c8e6c9
```
