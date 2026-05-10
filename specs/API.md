# API Specification

## Base Configuration

| Property | Value |
|---|---|
| Base URL | `http://{SERVER_HOST}:{SERVER_PORT}` (defaults: `localhost:8080`; both env-overridable) |
| Default Port | `8080` (from `.env`) |
| Protocol | HTTP |
| Content-Type | `application/json` |
| CORS | Driven by `CORS_ORIGIN` env (default `*`; comma-separated list supported for multi-origin allowlists) |

## Endpoints

### POST /calculate

Calculate the flight path from unordered flight segments.

**Request**

| Field | Type | Required | Description |
|---|---|---|---|
| body | `[][]string` | Yes | Array of flight segments, each `[source, destination]` |

```json
[["ATL", "EWR"], ["SFO", "ATL"]]
```

**Responses**

| Status | Body | Description |
|---|---|---|
| 200 | `["SFO", "EWR"]` | `[start_airport, end_airport]` |
| 400 | `{"Error": "..."}` | Invalid input (parse error, empty body, incomplete segment) |
| 500 | `{"Error": "..."}` | Reserved for unexpected server errors (not emitted by current handler) |

**Validation Rules**

| Rule | HTTP Status | Error Message |
|---|---|---|
| Empty payload `[]` | 400 | `"Flight segments cannot be empty"` |
| Segment with < 2 elements | 400 | `"Each flight segment must contain both source and destination"` (includes `Index`) |
| Unparseable JSON body | 400 | `"Can't parse the payload"` |

**Examples**

```
POST /calculate
Body: [["SFO", "EWR"]]
Response: ["SFO", "EWR"]

POST /calculate
Body: [["ATL", "EWR"], ["SFO", "ATL"]]
Response: ["SFO", "EWR"]

POST /calculate
Body: [["IND", "EWR"], ["SFO", "ATL"], ["GSO", "IND"], ["ATL", "GSO"]]
Response: ["SFO", "EWR"]
```

---

### GET /

Health check endpoint.

**Response**

| Status | Body |
|---|---|
| 200 | `{"data": "Server is up and running"}` |

---

### GET /swagger/*

Swagger UI for interactive API documentation (auto-generated OpenAPI 2.0 spec).

## Swagger Metadata

| Field | Value |
|---|---|
| Title | Flight Path API |
| Version | 1.0 |
| License | Apache 2.0 |
| Contact | Andriy Kalashnykov |
| Host | inferred at request time from the URL the spec was loaded from (no `host` field in the OpenAPI spec) |
| BasePath | / |
| Schemes | inferred at request time (no `schemes` field in the OpenAPI spec) |

## Middleware Stack

Applied in `internal/app/app.go` in this order:

1. **RequestID** — assigns each request a unique `X-Request-Id` header
2. **RequestLogger** — logs incoming requests (structured JSON, includes the request id)
3. **Recover** — recovers from panics, returns 500
4. **BodyLimit** — caps request bodies at 1 MiB (`1 << 20` bytes); oversized requests return 413
5. **Gzip** — content-encoding negotiation; gzip-encodes responses when the client sends `Accept-Encoding: gzip`
6. **RateLimiter** (in-memory store) — 100 req/s sustained, 200-request burst per IP; oversize returns 429. Tunable via `RATE_LIMIT_PER_SEC` (float, default 100) and `RATE_LIMIT_BURST` (int, default 200)
7. **CORS** — `Access-Control-Allow-Origin` derived from `CORS_ORIGIN` env. Empty / unset defaults to `*`. Supports a comma-separated list for multi-origin allowlists (e.g., `CORS_ORIGIN="https://app.example, https://admin.example"`)
8. **Secure** — sets `X-XSS-Protection: 1; mode=block`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`
9. **Cache-Control / CORP** (custom) — adds `Cache-Control: no-store` and `Cross-Origin-Resource-Policy: same-origin` to every response
