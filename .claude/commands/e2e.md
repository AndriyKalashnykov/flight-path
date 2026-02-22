Run end-to-end API tests against a local server instance:

1. Build the project: `make build`
2. Start the server in the background: `go run main.go -env-file .env &`
3. Wait a few seconds for the server to be ready (poll `http://localhost:8080/health` until it responds)
4. Run the E2E tests: `make e2e`
5. Capture the test results
6. Stop the server: kill the background process (`pkill -f "go run main.go"` or `lsof -ti:8080 | xargs kill -9`)
7. Report the E2E test results with pass/fail status for each test case

If the server fails to start (e.g., port 8080 is already in use), report the error and suggest a fix.
