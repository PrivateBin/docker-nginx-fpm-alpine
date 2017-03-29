FROM php:7.1-fpm-alpine

MAINTAINER Michael Contento <mail@michaelcontento.de>

RUN \
# Install dependencies
    apk add --no-cache nginx supervisor \
# Install PHP extension
    && docker-php-ext-install opcache \
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
    && chown www-data.www-data /var/www

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

ADD etc/ /etc/
ADD usr/ /usr/

EXPOSE 80

CMD ["/usr/bin/docker-start"]
