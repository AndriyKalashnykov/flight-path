#!/usr/bin/env bash

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$SCRIPT_DIR" || exit; cd ..; SCRIPT_PARENT_DIR=$(pwd);

GOCACHE=${GOCACHE:-$(go env GOCACHE)}
GOMODCACHE=${GOMODCACHE:-$(go env GOMODCACHE)}

CONTAINER_REGISTRY=andriykalashnykov
CONTAINER_IMAGE_NAME=flight-path
VERSION=$(cat "$(dirname "$0")/../pkg/api/version.txt" | tr -d '[:space:]')


cd "$SCRIPT_PARENT_DIR" || exit

builders="$(docker buildx ls | grep builder)"
if [[ $builders == "" ]]; then
        echo "No builder found, creating builder"
        docker buildx create --use --name builder --driver docker-container --bootstrap
else
        echo "Using existing builder"
fi

docker buildx build                                                   \
        --platform linux/amd64,linux/arm64,linux/arm/v7         \
        --build-arg GOCACHE=${GOCACHE}                          \
        --build-arg GOMODCACHE=${GOMODCACHE}                    \
        -t ${CONTAINER_REGISTRY}/${CONTAINER_IMAGE_NAME}:latest \
        -t ${CONTAINER_REGISTRY}/${CONTAINER_IMAGE_NAME}:${VERSION} \
        --push                                                  \
        .
# https://hub.docker.com/repository/docker/andriykalashnykov/flight-path/tags

cd "$LAUNCH_DIR" || exit
