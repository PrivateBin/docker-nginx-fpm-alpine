#!/bin/bash

# exit immediately on non-zero return code, including during a pipe stage or on
# accessing an uninitialized variable and print commands before executing them
set -euxo pipefail

IMAGE=privatebin/nginx-fpm-alpine
QEMU_PLATFORMS=linux/amd64,linux/386,linux/arm/v6,linux/arm/v7,linux/arm64,linux/ppc64le
VERSION=${GITHUB_REF##*/}
EVENT=$1
[ "${EVENT}" = "schedule" ] && VERSION=nightly

BUILDX_ARGS="--tag ${IMAGE}:latest \
--tag ${IMAGE}:${VERSION} --tag ${IMAGE}:${VERSION%%-*} \
--platform ${QEMU_PLATFORMS} ."
BUILDX_EDGE_ARGS="--tag ${IMAGE}:edge \
--platform ${QEMU_PLATFORMS} -f Dockerfile-edge ."

# build images
docker build --no-cache --pull --output "type=image,push=false" ${BUILDX_ARGS}
sed 's/^FROM alpine:.*$/FROM alpine:edge/' Dockerfile > Dockerfile-edge
docker build --no-cache --pull --output "type=image,push=false" ${BUILDX_EDGE_ARGS}

# push cached images
if [ "${EVENT}" != "pull_request" ] && ([ "${GITHUB_REF}" != "refs/heads/master" ] || [ "${EVENT}" = "schedule" ])
then
    printenv DOCKER_PASSWORD | docker login --username "${DOCKER_USERNAME}" --password-stdin
    docker build --output "type=image,push=true" ${BUILDX_ARGS}
    docker build --output "type=image,push=true" ${BUILDX_EDGE_ARGS}
    rm -f ${HOME}/.docker/config.json
fi

