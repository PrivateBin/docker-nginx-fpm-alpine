FROM php:fpm-alpine

MAINTAINER PrivateBin <support@privatebin.org>

RUN \
# Install dependencies
    apk add --no-cache nginx supervisor \
# Install PHP extension: opcache
    && docker-php-ext-install -j$(nproc) opcache \
    && rm -f /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
# Install PHP extension: gd
    && apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev \
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && apk del --no-cache freetype-dev libpng-dev libjpeg-turbo-dev \
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
# Bring php-fpm configs into a more controallable state
    && rm /usr/local/etc/php-fpm.d/www.conf.default \
    && mv /usr/local/etc/php-fpm.d/docker.conf /usr/local/etc/php-fpm.d/00-docker.conf \
    && mv /usr/local/etc/php-fpm.d/www.conf /usr/local/etc/php-fpm.d/10-www.conf \
    && mv /usr/local/etc/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/20-docker.conf \
# Install PrivateBin
    && apk add --no-cache gnupg \
    && cd /tmp \
    && curl -s https://codeload.github.com/PrivateBin/PrivateBin/tar.gz/1.1.1 | tar -xzf - \
    && rm -rf /var/www \
    && mv /tmp/PrivateBin-1.1.1 /var/www \
    && cd /var/www \
    && rm *.md \
    && mv cfg /srv \
    && mv lib /srv \
    && mv tpl /srv \
    && mv vendor /srv \
    && mkdir -p /srv/data \
    && sed -i "s#define('PATH', '');#define('PATH', '/srv/');#" index.php \
    && chown -R www-data.www-data /var/www /srv/* \
    && apk del --no-cache gnupg

WORKDIR /var/www

ADD etc/ /etc/
ADD usr/ /usr/

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /srv/data /srv/cfg/conf.php /tmp /var/tmp /var/run /var/log

EXPOSE 80

ENTRYPOINT ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
