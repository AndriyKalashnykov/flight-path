# syntax=docker/dockerfile:1@sha256:4a43a54dd1fedceb30ba47e76cfcf2b47304f4161c0caeac2db1c61804ea3c91

# build
FROM --platform=$BUILDPLATFORM golang:1.26-alpine@sha256:91eda9776261207ea25fd06b5b7fed8d397dd2c0a283e77f2ab6e91bfa71079d AS build
WORKDIR /app
COPY go.mod go.sum ./
ARG GOMODCACHE=/go/pkg/mod
ARG GOCACHE=/root/.cache/go-build
RUN --mount=type=cache,target="$GOMODCACHE" go mod download
ARG TARGETOS TARGETARCH
COPY . .
RUN --mount=type=cache,target="$GOMODCACHE" \
    --mount=type=cache,target="$GOCACHE" \
    CGO_ENABLED=0 GOOS="$TARGETOS" GOARCH="$TARGETARCH" go build -o /app/main .

# runtime image
FROM alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS runtime
WORKDIR /
# Weekly cache-bust for security updates. CI passes APK_UPGRADE_WEEK=$(date -u +%Y-W%V)
# as a build-arg so the `apk upgrade` layer re-runs at least once per week, picking
# up new CVE fixes from the Alpine package repo even when the Dockerfile is unchanged.
# Without this, the cached layer can serve stale package versions for weeks after a
# CVE is fixed upstream (e.g., CVE-2026-28390 openssl: apk repo has 3.5.6-r0 but the
# cached layer still ships 3.5.5-r0).
ARG APK_UPGRADE_WEEK=manual
RUN apk upgrade --no-cache
RUN addgroup -g 1000 srvgroup && \
    adduser -D srvuser -u 1000 -G srvgroup
USER srvuser:srvgroup

# runtime image
#FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3 AS runtime
#WORKDIR /
#COPY --from=build /app/main /
#CMD ["./main"]

#FROM gcr.io/distroless/static:nonroot
#WORKDIR /
#COPY --from=build /app/main /
#USER 65532:65532

COPY --from=build /app/main /

# HEALTHCHECK introspects the container itself, so the host portion is fixed
# to 127.0.0.1 (loopback inside the namespace). Port comes from $SERVER_PORT
# at runtime, falling back to 8080 to match .env. SERVER_HOST is also
# overridable for non-default bind addresses (e.g., binding to a sidecar
# proxy's loopback IP).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider \
      "http://${SERVER_HOST:-127.0.0.1}:${SERVER_PORT:-8080}/" || exit 1
ENTRYPOINT ["/main"]