#!/bin/bash

# exit immediately on non-zero return code, including during a pipe stage or on
# accessing an uninitialized variable and print commands before executing them
set -euxo pipefail

EVENT=$1
IMAGE=$2
EDGE=false
[ "$3" = edge ] && EDGE=true

build_image() {
    # shellcheck disable=SC2068
    docker build \
        --pull \
        --no-cache \
        --load \
        $@ \
        .
}

push_image() {
    # shellcheck disable=SC2068
    docker buildx build \
        --platform linux/amd64,linux/386,linux/arm/v6,linux/arm/v7,linux/arm64,linux/ppc64le \
        --pull \
        --no-cache \
        --push \
        $@ \
        .
}

docker_login() {
    printenv DOCKER_PASSWORD | docker login \
        --username "$DOCKER_USERNAME" \
        --password-stdin
}

is_image_push_required() {
    [ "$EVENT" != pull_request ] && { \
        [ "$GITHUB_REF" != refs/heads/master ] || \
        [ "$EVENT" = schedule ]
    }
}

main() {
    local TAG BUILD_ARGS

    if [ "$EVENT" = schedule ] ; then
        TAG=nightly
    else
        TAG=${GITHUB_REF##*/}
    fi

    case "$IMAGE" in
        fs)
            BUILD_ARGS="--build-arg ALPINE_PACKAGES= --build-arg COMPOSER_PACKAGES="
            ;;
        gcs)
            BUILD_ARGS="--build-arg ALPINE_PACKAGES=php81-openssl --build-arg COMPOSER_PACKAGES=google/cloud-storage"
            ;;
        pdo)
            BUILD_ARGS="--build-arg ALPINE_PACKAGES=php81-pdo_mysql,php81-pdo_pgsql --build-arg COMPOSER_PACKAGES="
            ;;
        s3)
            BUILD_ARGS="--build-arg ALPINE_PACKAGES=php81-openssl --build-arg COMPOSER_PACKAGES=aws/aws-sdk-php"
            ;;
        *)
            BUILD_ARGS=""
            ;;
    esac
    IMAGE="privatebin/$IMAGE"

    if [ "$EDGE" = true ] ; then
        sed -e 's/^FROM alpine:.*$/FROM alpine:edge/' Dockerfile > Dockerfile.edge
        BUILD_ARGS="-f Dockerfile.edge  --tag $IMAGE:edge $BUILD_ARGS"
        IMAGE="$IMAGE:edge"
    elif [ "$EVENT" = push ] ; then
        BUILD_ARGS="--tag $IMAGE:latest --tag $IMAGE:$TAG --tag ${IMAGE}:${TAG%%-*} --tag ${IMAGE}:stable $BUILD_ARGS"
        IMAGE="$IMAGE:latest"
    else
        BUILD_ARGS="--tag $IMAGE:latest --tag $IMAGE:$TAG --tag ${IMAGE}:${TAG%%-*} $BUILD_ARGS"
        IMAGE="$IMAGE:latest"
    fi
    build_image "$BUILD_ARGS"

    docker run -d --rm -p 127.0.0.1:8080:8080 --read-only --name smoketest "$IMAGE"
    sleep 5 # give the services time to start up and the log to collect any errors that might occur
    test "$(docker inspect --format="{{.State.Running}}" smoketest)" = true
    curl --silent --show-error -o /dev/null http://127.0.0.1:8080/
    if docker logs smoketest 2>&1 | grep -i -E "warn|emerg|fatal|panic|error"
    then
        exit 1
    fi
    docker stop smoketest

    if is_image_push_required ; then
        docker_login
        push_image "$BUILD_ARGS"
    fi

    rm -f Dockerfile.edge "$HOME/.docker/config.json"
}

[ "$(basename "$0")" = 'buildx.sh' ] && main
