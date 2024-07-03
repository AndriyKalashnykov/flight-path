#!/usr/bin/env bash

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

GOCACHE=${HOME}/Library/Caches/go-build
GOMODCACHE=${HOME}/go/pkg/mod

CONTAINER_REGISTRY=andriykalashnykov
CONTAINER_IMAGE_NAME=flight-path


cd $SCRIPT_PARENT_DIR

docker buildx create --name builder --driver docker-container --bootstrap
docker buildx use builder
docker buildx build                                             \
        --platform linux/amd64,linux/arm64                      \
        --build-arg GOCACHE=${GOCACHE}                          \
        --build-arg GOMODCACHE=${GOMODCACHE}                    \
        -t ${CONTAINER_REGISTRY}/${CONTAINER_IMAGE_NAME}:latest \
        --push                                                  \
        .

cd $LAUNCH_DIR