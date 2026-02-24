# Product Specification

## Problem Statement

There are over 100,000 flights a day, with millions of people and cargo being transferred around the world. With so many people and different carrier/agency groups, it can be hard to track where a person might be. In order to determine the flight path of a person, we must sort through all of their flight records.

## Goal

Create a simple microservice API that can help understand and track how a particular person's flight path may be queried.

## Functional Requirements

### FR-1: Flight Path Calculation

The API must accept a list of flight segments (each defined by a source and destination airport code) and return the overall start and end airports of the person's journey.

- **Input**: An unordered list of flight segments `[source, destination]`
- **Output**: The starting airport and the ending airport `[start, end]`
- Flights may not be listed in order and must be sorted to find the total flight path

### FR-2: Health Check

The API must expose a health check endpoint to verify the server is running.

### FR-3: API Documentation

The API must provide auto-generated Swagger/OpenAPI documentation accessible via a web UI.

## Non-Functional Requirements

### NFR-1: Performance

- The algorithm must operate in O(n) time complexity
- The service must handle datasets of 500+ flight segments efficiently
- Benchmark targets must be tracked and compared across changes

### NFR-2: Portability

- The service must run as a standalone binary (Linux amd64)
- The service must be containerized for multi-platform deployment (amd64, arm64, arm/v7)

### NFR-3: Code Quality

- Static analysis (golangci-lint, go-critic, gosec) must pass before builds
- E2E tests must pass in CI before merging

### NFR-4: Observability

- Request logging via middleware
- Panic recovery via middleware

## Assumptions

- Flight segments form a single connected path (no disconnected subgraphs)
- Each airport appears at most once as a source and once as a destination (simple path, no cycles)
- Airport codes are strings (IATA 3-letter codes by convention, not enforced at API level)

## Out of Scope

- Authentication / Authorization
- Rate limiting
- Database persistence
- Multi-person tracking
- Full itinerary reconstruction (intermediate stops) -- only start/end are returned
