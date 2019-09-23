FROM alpine:3.10

MAINTAINER PrivateBin <support@privatebin.org>

ENV RELEASE   1.3.1
ENV PBURL     https://github.com/PrivateBin/PrivateBin/
ENV S6RELEASE v1.22.1.0
ENV S6URL     https://github.com/just-containers/s6-overlay/releases/download/
ENV S6_READ_ONLY_ROOT 1

RUN \
# Install dependencies
    apk add --no-cache tzdata nginx php7-fpm php7-json php7-gd \
        php7-opcache php7-pdo_mysql php7-pdo_pgsql \
# Remove (some of the) default nginx config
    && rm -f /etc/nginx.conf /etc/nginx/conf.d/default.conf /etc/php7/php-fpm.d/www.conf \
    && rm -rf /etc/nginx/sites-* \
# Ensure nginx logs, even if the config has errors, are written to stderr
    && ln -s /dev/stderr /var/log/nginx/error.log \
# Install PrivateBin
    && apk add --no-cache gnupg curl libcap \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg2 --list-public-keys || /bin/true \
    && curl -s https://privatebin.info/key/release.asc | gpg2 --import - \
    && rm -rf /var/www/* \
    && cd /tmp \
    && curl -Ls ${PBURL}releases/download/${RELEASE}/PrivateBin-${RELEASE}.tar.gz.asc > PrivateBin-${RELEASE}.tar.gz.asc \
    && curl -Ls ${PBURL}archive/${RELEASE}.tar.gz > PrivateBin-${RELEASE}.tar.gz \
    && gpg2 --verify PrivateBin-${RELEASE}.tar.gz.asc \
    && cd /var/www \
    && tar -xzf /tmp/PrivateBin-${RELEASE}.tar.gz --strip 1 \
    && rm *.md cfg/conf.sample.php \
    && mv cfg /srv \
    && mv lib /srv \
    && mv tpl /srv \
    && mv vendor /srv \
    && mkdir -p /srv/data \
    && sed -i "s#define('PATH', '');#define('PATH', '/srv/');#" index.php \
# Install s6 overlay for service management
    && curl -s https://keybase.io/justcontainers/key.asc | gpg2 --import - \
    && cd /tmp \
    && curl -Ls ${S6URL}${S6RELEASE}/s6-overlay-amd64.tar.gz.sig > s6-overlay-amd64.tar.gz.sig \
    && curl -Ls ${S6URL}${S6RELEASE}/s6-overlay-amd64.tar.gz > s6-overlay-amd64.tar.gz \
    && gpg2 --verify s6-overlay-amd64.tar.gz.sig \
    && tar -xzf s6-overlay-amd64.tar.gz -C / \
# Support running s6 under a non-root user
    && mkdir -p /etc/services.d/nginx/supervise /etc/services.d/php-fpm7/supervise \
    && mkfifo /etc/services.d/nginx/supervise/control \
    && mkfifo /etc/services.d/php-fpm7/supervise/control \
    && mkfifo /etc/s6/services/s6-fdholderd/supervise/control \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx \
    && chown -R nobody.www-data /var/lib/nginx /var/tmp/nginx /var/www /srv/* /etc/services.d /etc/s6 /run \
# Clean up
    && rm -rf "${GNUPGHOME}" /tmp/* \
    && apk del gnupg curl libcap

COPY etc/ /etc/

WORKDIR /var/www
USER nobody:www-data

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /srv/data /tmp /var/tmp/nginx /run /var/log

EXPOSE 80

ENTRYPOINT ["/init"]
