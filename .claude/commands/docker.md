Build and test the Docker image locally:

1. Run pre-build checks: `make lint` and `make test`
2. Build the Docker image: `make build-image`
3. If the build succeeds, run the container: `docker run -d -p 8080:8080 --name flight-path-test flight-path:latest`
4. Wait for the container to be ready (poll `http://localhost:8080/health`)
5. Run a quick smoke test using curl against the `/calculate` endpoint with test data: `[["SFO","ATL"],["ATL","EWR"]]`
6. Report the health check and smoke test results
7. Stop and remove the test container: `docker stop flight-path-test && docker rm flight-path-test`

If port 8080 is already in use, report the conflict and suggest a fix before proceeding.
