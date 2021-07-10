FROM alpine:3.14

ARG RELEASE=1.3.5
ARG ALPINE_PACKAGES="php8-pdo_mysql php8-pdo_pgsql"
ARG COMPOSER_PACKAGES="google/cloud-storage"

MAINTAINER PrivateBin <support@privatebin.org>

ENV RELEASE           1.3.5
ENV PBURL             https://github.com/PrivateBin/PrivateBin/
ENV S6_READ_ONLY_ROOT 1
ENV CONFIG_PATH       /srv/cfg


ADD install.sh /tmp
RUN /tmp/install.sh -r $RELEASE -p "$ALPINE_PACKAGES" -c "$COMPOSER_PACKAGES"

COPY etc/ /etc/

WORKDIR /var/www
# user nobody, group www-data
USER 65534:82

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 8080

ENTRYPOINT ["/init"]
