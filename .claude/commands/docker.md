Build and test the Docker image locally:

1. Run pre-build checks: `make lint` and `make test`
2. Build the Docker image locally: `make image-build` (produces `flight-path:local`)
3. Simplest path: `make image-test` — builds, runs the container on a free host port, and runs the smoke + structure tests. To do it by hand instead: `make image-run` (binds an ephemeral host port, `--env-file .env.example`), then `make image-smoke-test`
4. Report the health check and smoke test results
5. Tear down: `make image-stop`

The image runs fine without a `.env` (the port defaults to 8080; override with `SERVER_PORT`). `make image-run` picks a free host port automatically, so port-8080 conflicts don't arise; if you run a manual `docker run -p 8080:8080`, report any conflict first.
