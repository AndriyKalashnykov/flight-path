# build
FROM --platform=$BUILDPLATFORM golang:1.23-alpine@sha256:2c49857f2295e89b23b28386e57e018a86620a8fede5003900f2d138ba9c4037 AS build
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
FROM alpine:3.21.2@sha256:56fa17d2a7e7f168a043a2712e63aed1f8543aeafdcee47c58dcffe38ed51099 AS runtime
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