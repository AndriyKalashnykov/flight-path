# API Specification

## Base Configuration

| Property | Value |
|---|---|
| Base URL | `http://localhost:{SERVER_PORT}` |
| Default Port | `8080` (from `.env`) |
| Protocol | HTTP |
| Content-Type | `application/json` |
| CORS | All origins allowed (`*`) |

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
| 400 | `{"Error": "..."}` | Invalid input |
| 500 | `{"Error": "..."}` | Server/parsing error |

**Validation Rules**

| Rule | HTTP Status | Error Message |
|---|---|---|
| Empty payload `[]` | 400 | `"Flight segments cannot be empty"` |
| Segment with < 2 elements | 400 | `"Each flight segment must contain both source and destination"` (includes `Index`) |
| Unparseable JSON body | 500 | `"Can't parse the payload"` |

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
| Host | localhost:8080 |
| BasePath | / |
| Schemes | http |

## Middleware Stack

1. **RequestLogger** - Logs incoming requests
2. **Recover** - Recovers from panics, returns 500
3. **CORS** - Allows all origins (`*`)
