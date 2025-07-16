#!/usr/bin/env bash

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

GOCACHE=${HOME}/Library/Caches/go-build
GOMODCACHE=${HOME}/go/pkg/mod

CONTAINER_REGISTRY=andriykalashnykov
CONTAINER_IMAGE_NAME=flight-path


cd $SCRIPT_PARENT_DIR

builders="$(docker buildx ls | grep builder)"
if [[ $builders == "" ]]; then
        echo "No builder found, creating builder"
        docker buildx create --use --name builder --driver docker-container --bootstrap
else
        echo "Using existing builder"
fi

docker buildx build                                             \
        --platform linux/amd64,linux/arm64,linux/arm/v7         \
        --build-arg GOCACHE=${GOCACHE}                          \
        --build-arg GOMODCACHE=${GOMODCACHE}                    \
        -t ${CONTAINER_REGISTRY}/${CONTAINER_IMAGE_NAME}:latest \
        --push                                                  \
        .
# https://hub.docker.com/repository/docker/andriykalashnykov/flight-path/tags

cd $LAUNCH_DIR