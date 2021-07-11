#!/bin/bash

# exit immediately on non-zero return code, including during a pipe stage or on
# accessing an uninitialized variable and print commands before executing them
set -euxo pipefail

EVENT=$1
VERSION=${GITHUB_REF##*/}


build_image() {
   local push build_args
   push=$1; shift 1;
   build_args="$@"

   docker buildx build \
         --platform linux/amd64,linux/386,linux/arm/v6,linux/arm/v7,linux/arm64,linux/ppc64le \
         --output type=image,push=$push \
         --pull \
         --no-cache \
         --progress plain \
         $build_args \
         .
}

image_build_arguments() {
    cat<<!
privatebin/fs  --build-arg ALPINE_PACKAGES= --build-arg COMPOSER_PACKAGES=
privatebin/pdo --build-arg COMPOSER_PACKAGES=
privatebin/gcs --build-arg ALPINE_PACKAGES=
privatebin/nginx-fpm-alpine
!
}

docker_login() {
    printenv DOCKER_PASSWORD | docker login --username "$DOCKER_USERNAME" --password-stdin
}

is_image_push_required() {
   [[ $EVENT != pull_request ]] && ([[ $GITHUB_REF != refs/heads/master ]] || [[ $EVENT = schedule ]])
}

main() {
    local push tag image build_args

    # tag the image with nightly, if it is the scheduled event

    [[ $EVENT == schedule ]] && tag=nightly || tag=$VERSION
    if is_image_push_required; then
        push=true
        docker_login
    else
        push=false
    fi

    image_build_arguments | while read image build_args ; do
        build_image $push --tag $image:latest  --tag $image:$tag "$build_args"
    done

    sed -e 's/^FROM alpine:.*$/FROM alpine:edge/' Dockerfile > Dockerfile.edge

    image_build_arguments | while read image build_args ; do
	build_image $push -f Dockerfile.edge --tag $image:edge "$build_args"
    done

    rm -f Dockerfile.edge

    rm -f "$HOME/.docker/config.json"
}

main
