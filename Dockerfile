FROM alpine:3.13

MAINTAINER PrivateBin <support@privatebin.org>

ENV RELEASE   1.3.5
ENV PBURL     https://github.com/PrivateBin/PrivateBin/
ENV S6_READ_ONLY_ROOT 1

RUN \
# Install dependencies
    apk add --no-cache gnupg nginx php8-fpm php8-json php8-gd \
        php8-opcache php8-pdo_mysql php8-pdo_pgsql s6-overlay tzdata \
    && apk upgrade --no-cache \
# Remove (some of the) default nginx config
    && rm -f /etc/nginx.conf /etc/nginx/http.d/default.conf /etc/php8/php-fpm.d/www.conf \
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
# Support running s6 under a non-root user
    && mkdir -p /etc/s6/services/nginx/supervise /etc/s6/services/php-fpm8/supervise \
    && mkfifo \
        /etc/s6/services/nginx/supervise/control \
        /etc/s6/services/php-fpm8/supervise/control \
    && adduser nobody www-data \
    && chown -R nobody.www-data /etc/s6 /run /srv/* /var/lib/nginx /var/www \
# Clean up
    && rm -rf "${GNUPGHOME}" /tmp/* \
    && apk del gnupg

COPY etc/ /etc/

WORKDIR /var/www
# user nobody, group www-data
USER 65534:82

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 8080

ENTRYPOINT ["/init"]
