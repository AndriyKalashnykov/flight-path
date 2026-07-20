# syntax=docker/dockerfile:1@sha256:4a43a54dd1fedceb30ba47e76cfcf2b47304f4161c0caeac2db1c61804ea3c91

# build
FROM --platform=$BUILDPLATFORM golang:1.26-alpine@sha256:0178a641fbb4858c5f1b48e34bdaabe0350a330a1b1149aabd498d0699ff5fb2 AS build
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
FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS runtime
WORKDIR /
# Daily cache-bust for security updates. CI passes APK_UPGRADE_DATE=$(date -u +%Y-%m-%d)
# as a build-arg so the `apk upgrade` layer re-runs at least once per day, picking
# up new CVE fixes from the Alpine package repo even when the Dockerfile is unchanged.
# Without this, the cached layer can serve stale package versions after a CVE is fixed
# upstream (e.g., CVE-2026-45447 openssl: apk repo has 3.5.7-r0 but a stale weekly-keyed
# cache layer still shipped 3.5.6-r0 — daily granularity bounds that staleness to <24h).
ARG APK_UPGRADE_DATE=manual
RUN apk upgrade --no-cache
# Non-root runtime user. UID/GID are ARGs so consumers can align them with a
# host volume's ownership without editing the Dockerfile; defaults match the
# container-structure-test expectation (srvuser:x:1000:1000).
ARG APP_UID=1000
ARG APP_GID=1000
RUN addgroup -g ${APP_GID} srvgroup && \
    adduser -D srvuser -u ${APP_UID} -G srvgroup
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

# Bind port. ARG sets the build-time default; ENV exposes it to the app
# (app.Port() reads SERVER_PORT) and to the HEALTHCHECK CMD below, so a single
# `--build-arg APP_INTERNAL_PORT=…` moves the listen port and its probe in
# lockstep. Still overridable at runtime with `-e SERVER_PORT=…`.
ARG APP_INTERNAL_PORT=8080
ENV SERVER_PORT=${APP_INTERNAL_PORT}
EXPOSE ${APP_INTERNAL_PORT}

# HEALTHCHECK introspects the container itself, so the host portion is fixed
# to 127.0.0.1 (loopback inside the namespace). Port comes from $SERVER_PORT
# at runtime, falling back to 8080 to match .env. SERVER_HOST is also
# overridable for non-default bind addresses (e.g., binding to a sidecar
# proxy's loopback IP).
# (HEALTHCHECK timing flags are parse-time literals — they cannot be ARG/ENV-
# expanded, so they intentionally stay as literals per the param-externalization rule.)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider \
      "http://${SERVER_HOST:-127.0.0.1}:${SERVER_PORT:-8080}/" || exit 1
ENTRYPOINT ["/main"]