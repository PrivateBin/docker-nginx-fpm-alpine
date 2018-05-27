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
# Remove default content from the default $DOCUMENT_ROOT ...
    && rm -rf /var/www \
# ... but ensure it exists with the right owner
    && mkdir -p /var/www \
    && echo "<?php phpinfo();" > /var/www/index.php \
    && chown -R www-data.www-data /var/www \
# Bring php-fpm configs into a more controallable state
    && rm /usr/local/etc/php-fpm.d/www.conf.default \
    && mv /usr/local/etc/php-fpm.d/docker.conf /usr/local/etc/php-fpm.d/00-docker.conf \
    && mv /usr/local/etc/php-fpm.d/www.conf /usr/local/etc/php-fpm.d/10-www.conf \
    && mv /usr/local/etc/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/20-docker.conf

WORKDIR /var/www

ADD etc/ /etc/
ADD usr/ /usr/

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /tmp /var/tmp /var/run /var/log

EXPOSE 80

ENTRYPOINT ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
