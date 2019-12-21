FROM alpine:3.11

MAINTAINER PrivateBin <support@privatebin.org>

ENV RELEASE   1.2.1
ENV PBURL     https://github.com/PrivateBin/PrivateBin/
ENV S6RELEASE v1.22.1.0
ENV S6URL     https://github.com/just-containers/s6-overlay/releases/download/
ENV S6_READ_ONLY_ROOT 1

RUN \
# Install dependencies
    apk add --no-cache gnupg libcap nginx php7-fpm php7-json php7-gd \
        php7-opcache php7-pdo_mysql php7-pdo_pgsql tzdata \
# Remove (some of the) default nginx config
    && rm -f /etc/nginx.conf /etc/nginx/conf.d/default.conf /etc/php7/php-fpm.d/www.conf \
    && rm -rf /etc/nginx/sites-* \
# Ensure nginx logs, even if the config has errors, are written to stderr
    && ln -s /dev/stderr /var/log/nginx/error.log \
# Install PrivateBin
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg2 --list-public-keys || /bin/true \
    && wget -qO - https://privatebin.info/key/release.asc | gpg2 --import - \
    && rm -rf /var/www/* \
    && cd /tmp \
    && wget -qO ${RELEASE}.tar.gz.asc ${PBURL}releases/download/${RELEASE}/PrivateBin-${RELEASE}.tar.gz.asc \
    && wget -q ${PBURL}archive/${RELEASE}.tar.gz \
    && gpg2 --verify ${RELEASE}.tar.gz.asc \
    && cd /var/www \
    && tar -xzf /tmp/${RELEASE}.tar.gz --strip 1 \
    && rm *.md cfg/conf.sample.php \
    && mv cfg lib tpl vendor /srv \
    && mkdir -p /srv/data \
    && sed -i "s#define('PATH', '');#define('PATH', '/srv/');#" index.php \
# Install s6 overlay for service management
    && wget -qO - https://keybase.io/justcontainers/key.asc | gpg2 --import - \
    && cd /tmp \
    && S6ARCH=$(uname -m) \
    && case ${S6ARCH} in \
           x86_64) S6ARCH=amd64;; \
           armv7l) S6ARCH=armhf;; \
       esac \
    && wget -q ${S6URL}${S6RELEASE}/s6-overlay-${S6ARCH}.tar.gz.sig \
    && wget -q ${S6URL}${S6RELEASE}/s6-overlay-${S6ARCH}.tar.gz \
    && gpg2 --verify s6-overlay-${S6ARCH}.tar.gz.sig \
    && tar -xzf s6-overlay-${S6ARCH}.tar.gz -C / \
# Support running s6 under a non-root user
    && mkdir -p /etc/services.d/nginx/supervise /etc/services.d/php-fpm7/supervise \
    && mkfifo \
        /etc/services.d/nginx/supervise/control \
        /etc/services.d/php-fpm7/supervise/control \
        /etc/s6/services/s6-fdholderd/supervise/control \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx \
    && chown -R nobody.www-data /etc/services.d /etc/s6 /run /srv/* /var/lib/nginx /var/www \
# Clean up
    && rm -rf "${GNUPGHOME}" /tmp/* \
    && apk del gnupg libcap

COPY etc/ /etc/

WORKDIR /var/www
USER nobody:www-data

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 80 8080

ENTRYPOINT ["/init"]
