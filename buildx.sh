#!/bin/bash

# exit immediately on non-zero return code, including during a pipe stage or on
# accessing an uninitialized variable and print commands before executing them
set -euxo pipefail

EVENT=$1

build_image() {
    local PUSH
    PUSH=$1
    shift 1

    docker buildx build \
        --platform linux/amd64,linux/386,linux/arm/v6,linux/arm/v7,linux/arm64,linux/ppc64le \
        --output type=image,push="$PUSH" \
        --pull \
        --no-cache \
        --progress plain \
        $@ \
        .
}

docker_login() {
    printenv DOCKER_PASSWORD | docker login \
        --username "$DOCKER_USERNAME" \
        --password-stdin
}

image_build_arguments() {
    cat<<!
privatebin/fs  --build-arg ALPINE_PACKAGES= --build-arg COMPOSER_PACKAGES=
privatebin/pdo --build-arg ALPINE_PACKAGES=php8-pdo_mysql,php8-pdo_pgsql --build-arg COMPOSER_PACKAGES=
privatebin/gcs --build-arg ALPINE_PACKAGES=php8-openssl
privatebin/nginx-fpm-alpine
!
}

is_image_push_required() {
    [ "$EVENT" != pull_request ] && { \
        [ "$GITHUB_REF" != refs/heads/master ] || \
        [ "$EVENT" = schedule ]
    }
}

main() {
    local PUSH TAG IMAGE BUILD_ARGS

    if [ "$EVENT" = schedule ] ; then
        TAG=nightly
    else
        TAG=${GITHUB_REF##*/}
    fi

    if is_image_push_required ; then
        PUSH=true
        docker_login
    else
        PUSH=false
    fi

    sed -e 's/^FROM alpine:.*$/FROM alpine:edge/' Dockerfile > Dockerfile.edge

    image_build_arguments | while read -r IMAGE BUILD_ARGS ; do
        build_image $PUSH --tag "$IMAGE:latest" --tag "$IMAGE:$TAG" --tag "${IMAGE}:${TAG%%-*}" "$BUILD_ARGS"
        build_image $PUSH -f Dockerfile.edge    --tag "$IMAGE:edge" "$BUILD_ARGS"
    done

    rm -f Dockerfile.edge "$HOME/.docker/config.json"
}

[ "$(basename "$0")" = 'buildx.sh' ] && main
