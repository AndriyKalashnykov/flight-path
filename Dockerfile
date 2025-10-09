# build
FROM --platform=$BUILDPLATFORM golang:1.25-alpine@sha256:182059d7dae0e1dfe222037d14b586ebece3ebf9a873a0fe1cc32e53dbea04e0 AS build
WORKDIR /app
COPY go.mod go.sum ./
ARG GOMODCACHE GOCACHE
RUN --mount=type=cache,target="$GOMODCACHE" go mod download
ARG TARGETOS TARGETARCH
COPY . .
RUN --mount=type=cache,target="$GOMODCACHE" \
    --mount=type=cache,target="$GOCACHE" \
    CGO_ENABLED=0 GOOS="$TARGETOS" GOARCH="$TARGETARCH" go build -o /app/main .

# runtime image
FROM alpine:3.22.2@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412 AS runtime
WORKDIR /
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
CMD ["/bin/sh", "-c", "./main"]
ENTRYPOINT [ "./main" ]