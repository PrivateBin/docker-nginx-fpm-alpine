FROM alpine:3.10.0

MAINTAINER PrivateBin <support@privatebin.org>

ENV RELEASE 1.2.1

RUN \
# Install dependencies
    apk add --no-cache supervisor nginx php7-fpm php7-json php7-gd php7-opcache \
        php7-pdo_mysql php7-pdo_pgsql \
# Remove (some of the) default nginx config
    && rm -f /etc/nginx.conf \
    && rm -f /etc/nginx/conf.d/default.conf \
    && rm -rf /etc/nginx/sites-* \
    && rm -rf /var/log/nginx \
# Ensure nginx logs, even if the config has errors, are written to stderr
    && rm /var/lib/nginx/logs \
    && mkdir -p /var/lib/nginx/logs \
    && ln -s /dev/stderr /var/lib/nginx/logs/error.log \
# Create folder where the user hook into our default configs
    && mkdir -p /etc/nginx/server.d/ \
    && mkdir -p /etc/nginx/location.d/ \
# Install PrivateBin
    && apk add --no-cache gnupg curl \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg2 --list-public-keys || /bin/true \
    && curl -s https://privatebin.info/key/release.asc | gpg2 --import - \
    && rm -rf /var/www/* \
    && cd /tmp \
    && curl -Ls https://github.com/PrivateBin/PrivateBin/releases/download/${RELEASE}/PrivateBin-${RELEASE}.tar.gz.asc > PrivateBin-${RELEASE}.tar.gz.asc \
    && curl -Ls https://github.com/PrivateBin/PrivateBin/archive/${RELEASE}.tar.gz > PrivateBin-${RELEASE}.tar.gz \
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
    && chown -R nobody.www-data /var/www /srv/* \
    && rm -rf "${GNUPGHOME}" /tmp/* \
    && apk del --no-cache gnupg curl

WORKDIR /var/www

ADD etc/ /etc/

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /srv/data /tmp /var/tmp /run /var/log

EXPOSE 80

ENTRYPOINT ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
