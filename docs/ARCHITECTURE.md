# Architecture

C4 model diagrams and request/CI workflow diagrams for the Flight Path API.

## C4 Context Diagram

Shows the system boundary and external actors interacting with the Flight Path API.

```mermaid
C4Context
    title System Context Diagram - Flight Path API

    Person(user, "API Client", "Developer or application consuming the Flight Path API")

    System(flightpath, "Flight Path API", "Go microservice that calculates flight paths from unordered flight segments")

    System_Ext(swagger, "Swagger UI", "Auto-generated API documentation and interactive testing")
    System_Ext(ci, "GitHub Actions CI", "Automated build, test, security scan, and image scan pipeline")

    Rel(user, flightpath, "POST /calculate, GET /", "HTTP/JSON")
    Rel(user, swagger, "Browses API docs", "HTTP")
    Rel(swagger, flightpath, "Serves from /swagger/*", "HTTP")
    Rel(ci, flightpath, "Builds, tests, scans", "CI pipeline")

    UpdateLayoutConfig($c4ShapeInRow="3")
```

## C4 Container Diagram

flight-path ships as **one runnable container** — a statically-linked Go binary
that embeds the HTTP server, routing, handlers, the `FindItinerary` algorithm,
and the Swagger UI (via `swaggo/echo-swagger`). The diagram below matches that
reality. For the internal module structure inside that one container (routes,
handlers, algorithm, data models) see the Component diagram below.

```mermaid
C4Container
    title Container Diagram - Flight Path API

    Person(client, "API Client", "cURL, Postman, Newman, browser")

    System_Boundary(api, "Flight Path API") {
        Container(server, "flight-path server", "Go 1.26.2, Echo v5.1.0", "Single static binary. Serves POST /calculate, GET /, and GET /swagger/* (embedded Swagger UI via swaggo/echo-swagger v2.0.1). Middleware stack: Logger, Recover, CORS, Secure, Cache-Control, Gzip, RequestID, BodyLimit 1 MiB.")
    }

    System_Ext(ci, "GitHub Actions CI", "Builds, tests, scans, signs")
    System_Ext(ghcr, "GHCR", "Hosts multi-arch signed container images")
    System_Ext(sigstore, "Sigstore", "Cosign keyless OIDC signing + Rekor transparency log")

    Rel(client, server, "POST /calculate, GET /, GET /swagger/*", "HTTPS / JSON")
    Rel(ci, server, "Builds, tests, image-scans", "make ci / make image-scan")
    Rel(ci, ghcr, "Publishes images (on tag push)", "docker push")
    Rel(ci, sigstore, "Signs manifests by digest", "cosign OIDC")

    UpdateLayoutConfig($c4ShapeInRow="3")
```

## C4 Component Diagram

Shows the internal components and their relationships.

```mermaid
C4Component
    title Component Diagram - Flight Path API

    Container_Boundary(main_boundary, "main.go") {
        Component(entrypoint, "main()", "Entry Point", "Loads .env, creates Echo instance, registers middleware and routes, starts server")
    }

    Container_Boundary(routes_boundary, "internal/routes/") {
        Component(flight_routes, "FlightRoutes", "Route Registration", "POST /calculate -> FlightCalculate")
        Component(health_routes, "HealthcheckRoutes", "Route Registration", "GET / -> ServerHealthCheck")
        Component(swagger_routes, "SwaggerRoutes", "Route Registration", "GET /swagger/* -> Swagger UI")
    }

    Container_Boundary(handlers_boundary, "internal/handlers/") {
        Component(handler_struct, "Handler struct", "Constructor", "New() creates Handler instance")
        Component(flight_handler, "FlightCalculate", "Handler Method", "Binds [][]string, validates segments, calls FindItinerary, returns [start, end]")
        Component(health_handler, "ServerHealthCheck", "Handler Method", "Returns server status JSON")
        Component(find_itinerary, "FindItinerary", "Algorithm", "O(n) two-pass map algorithm: finds airport with no incoming (start) and no outgoing (end)")
    }

    Container_Boundary(pkg_boundary, "pkg/api/") {
        Component(flight_model, "Flight", "Data Model", "struct { Start string, End string }")
    }

    Rel(entrypoint, flight_routes, "Registers")
    Rel(entrypoint, health_routes, "Registers")
    Rel(entrypoint, swagger_routes, "Registers")
    Rel(flight_routes, flight_handler, "Routes to")
    Rel(health_routes, health_handler, "Routes to")
    Rel(flight_handler, find_itinerary, "Calls")
    Rel(find_itinerary, flight_model, "Uses")
    Rel(flight_handler, flight_model, "Converts payload to")
```

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

## CI/CD Pipeline

GitHub Actions workflow showing the build, test, and security scanning pipeline.

```mermaid
flowchart TD
    trigger["Push / Pull Request"] --> static

    subgraph static["Static Check"]
        lint["golangci-lint<br/>(60+ linters)"]
        sec["gosec<br/>(security scanner)"]
        vuln["govulncheck<br/>(dependency CVEs)"]
        secrets["gitleaks<br/>(secrets detection)"]
        actionlint["actionlint<br/>(CI lint)"]
        trivyfs["Trivy filesystem<br/>(vuln + secret + misconfig)"]
    end

    static --> builds["Build Binary"]
    builds --> tests

    subgraph tests["Tests"]
        unit["Unit + Handler Tests<br/>(go test ./...)"]
        fuzz["Fuzz Tests<br/>(30 seconds)"]
    end

    builds --> imgscan

    subgraph imgscan["Image Scan"]
        docker["Build Docker Image"]
        trivyimg["Trivy Image Scan<br/>(CRITICAL + HIGH)"]
        docker --> trivyimg
    end

    tests --> integration

    subgraph integration["Integration Tests"]
        start["Build + Start Server"]
        newman["Newman/Postman E2E<br/>(6 test cases)"]
        start --> newman
    end

    integration --> dast

    subgraph dast["DAST"]
        zapstart["Build + Start Server"]
        zap["OWASP ZAP API Scan<br/>(via Swagger spec)"]
        zapstart --> zap
    end

    style static fill:#e1f5fe
    style tests fill:#e8f5e9
    style integration fill:#fff3e0
    style dast fill:#fce4ec
    style imgscan fill:#f3e5f5
```
