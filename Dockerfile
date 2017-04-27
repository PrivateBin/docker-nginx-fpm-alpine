FROM php:fpm-alpine

MAINTAINER Michael Contento <mail@michaelcontento.de>

RUN \
# Install dependencies
    apk add --no-cache nginx supervisor \
# Install PHP extension: opcache
    && docker-php-ext-install opcache \
    && rm -f /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
# Install PHP extension: xdebug
    && apk add --no-cache g++ make autoconf \
    && pecl install xdebug \
    && apk del g++ make autoconf \
    && rm -rf /tmp/pear \
# Remove (some of the) default nginx config
    && rm -f /etc/nginx.conf \
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

# Where nginx should serve from
ENV DOCUMENT_ROOT=/var/www

# Should we instantiate a redirect for apex-to-www? Or www-to-apex?
# Valid values are "none", "www-to-apex" or "apex-to-www"
ENV REDIRECT_MODE="none"

# Which HTTP code should we use for the above redirect
ENV REDIRECT_CODE=302

# Which protocol should we use to do the above redirect? Valid options are
# "http", "https" or "auto" (which will trust X-Forwarded-Proto)
ENV REDIRECT_PROTO="auto"

# Change this to true/1 to enable the xdebug extension for php. You need to change
# some xdebug settings? E.g. xdebug.idekey? Just set a environment variable with the dot
# replaced with an underscore (xdebug.idekey => XDEBUG_IDEKEY) and they xdebug config will
# be changed on container start. This is a fast and simple alternative to adding a custom
# config ini in /usr/local/etc/php/conf.d/
ENV XDEBUG=false

# Which environment variables should be available to PHP? For security reasons we do not expose
# any of them to PHP by default.
# Valid values are "none" and "all"
ENV ENV_WHITELIST="none"

ADD etc/ /etc/
ADD usr/ /usr/

EXPOSE 80

CMD ["/usr/bin/docker-start"]
