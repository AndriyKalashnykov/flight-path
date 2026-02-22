Guide me through adding a new API endpoint to this project. Follow these steps:

1. Ask for: endpoint path, HTTP method, description, request/response types
2. Create the handler in `internal/handlers/` with full Swagger annotations
3. Add input validation
4. Register the route in `internal/routes/`
5. Wire the route in `main.go`
6. Write table-driven unit tests
7. Run `make api-docs` to regenerate Swagger docs
8. Run `make test` to verify tests pass
9. Run `make lint` to check code quality

Follow the patterns in existing handlers (see `internal/handlers/flight.go`) and routes (see `internal/routes/flight.go`).
