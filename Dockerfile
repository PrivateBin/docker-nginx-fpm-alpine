FROM alpine:3.21

ARG ALPINE_PACKAGES="php84-iconv php84-pdo_mysql php84-pdo_pgsql php84-openssl php84-simplexml"
ARG COMPOSER_PACKAGES="aws/aws-sdk-php google/cloud-storage"
ARG PBURL=https://github.com/PrivateBin/PrivateBin/
ARG RELEASE=1.7.6
ARG UID=65534
ARG GID=82

ENV CONFIG_PATH=/srv/cfg
ENV PATH=$PATH:/srv/bin

LABEL org.opencontainers.image.authors=support@privatebin.org \
      org.opencontainers.image.vendor=PrivateBin \
      org.opencontainers.image.documentation=https://github.com/PrivateBin/docker-nginx-fpm-alpine/blob/master/README.md \
      org.opencontainers.image.source=https://github.com/PrivateBin/docker-nginx-fpm-alpine \
      org.opencontainers.image.licenses=zlib-acknowledgement \
      org.opencontainers.image.version=${RELEASE}

COPY release.asc /tmp/

RUN \
# Prepare composer dependencies
    ALPINE_PACKAGES="$(echo ${ALPINE_PACKAGES} | sed 's/,/ /g')" ;\
    ALPINE_COMPOSER_PACKAGES="" ;\
    if [ -n "${COMPOSER_PACKAGES}" ] ; then \
        # we need these PHP 8.3 packages until composer gets updated to depend on PHP 8.4
        ALPINE_COMPOSER_PACKAGES="composer" ;\
        if [ -n "${ALPINE_PACKAGES##*php83-curl*}" ] ; then \
            ALPINE_COMPOSER_PACKAGES="php83-curl ${ALPINE_COMPOSER_PACKAGES}" ;\
        fi ;\
        if [ -n "${ALPINE_PACKAGES##*php83-mbstring*}" ] ; then \
            ALPINE_COMPOSER_PACKAGES="php83-mbstring ${ALPINE_COMPOSER_PACKAGES}" ;\
        fi ;\
        if [ -z "${ALPINE_PACKAGES##*php84-simplexml*}" ] ; then \
            ALPINE_COMPOSER_PACKAGES="php83-simplexml ${ALPINE_COMPOSER_PACKAGES}" ;\
        fi ;\
    fi \
# Install dependencies
    && apk upgrade --no-cache \
    && apk add --no-cache gnupg git nginx php84 php84-ctype php84-fpm php84-gd \
        php84-opcache s6 tzdata ${ALPINE_PACKAGES} ${ALPINE_COMPOSER_PACKAGES} \
# Stabilize php config location
    && mv /etc/php84 /etc/php \
    && ln -s /etc/php /etc/php84 \
    && ln -s $(which php84) /usr/local/bin/php \
# Remove (some of the) default nginx & php config
    && rm -f /etc/nginx.conf /etc/nginx/http.d/default.conf /etc/php/php-fpm.d/www.conf \
    && rm -rf /etc/nginx/sites-* \
# Ensure nginx logs, even if the config has errors, are written to stderr
    && ln -s /dev/stderr /var/log/nginx/error.log \
# Install PrivateBin
    && cd /tmp \
    && export GNUPGHOME="$(mktemp -d -p /tmp)" \
    && gpg2 --list-public-keys || /bin/true \
    && gpg2 --import /tmp/release.asc \
    && rm -rf /var/www/* \
    && if expr "${RELEASE}" : '[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}$' >/dev/null ; then \
         echo "getting release ${RELEASE}"; \
         wget -qO ${RELEASE}.tar.gz.asc ${PBURL}releases/download/${RELEASE}/PrivateBin-${RELEASE}.tar.gz.asc \
         && wget -q ${PBURL}archive/${RELEASE}.tar.gz \
         && gpg2 --verify ${RELEASE}.tar.gz.asc ; \
       else \
         echo "getting tarball for ${RELEASE}"; \
         git clone ${PBURL%%/}.git -b ${RELEASE}; \
         (cd $(basename ${PBURL}) && git archive --prefix ${RELEASE}/ --format tgz ${RELEASE} > /tmp/${RELEASE}.tar.gz); \
       fi \
    && cd /var/www \
    && tar -xzf /tmp/${RELEASE}.tar.gz --strip 1 \
    && if [ -n "${COMPOSER_PACKAGES}" ] ; then \
        composer remove --dev --no-update phpunit/phpunit \
        && composer config --unset platform \
        && composer require --no-update ${COMPOSER_PACKAGES} \
        && composer update --no-dev --optimize-autoloader \
        rm /usr/local/bin/* ;\
    fi \
    && rm *.md cfg/conf.sample.php \
    && mv bin cfg lib tpl vendor /srv \
    && mkdir -p /srv/data \
    && sed -i "s#define('PATH', '');#define('PATH', '/srv/');#" index.php \
# Support running s6 under a non-root user
    && mkdir -p /etc/s6/services/nginx/supervise /etc/s6/services/php-fpm84/supervise \
    && mkfifo \
        /etc/s6/services/nginx/supervise/control \
        /etc/s6/services/php-fpm84/supervise/control \
    && chown -R ${UID}:${GID} /etc/s6 /run /srv/* /var/lib/nginx /var/www \
    && chmod o+rwx /run /var/lib/nginx /var/lib/nginx/tmp \
# Clean up
    && gpgconf --kill gpg-agent \
    && rm -rf /tmp/* composer.* \
    && apk del --no-cache gnupg git ${ALPINE_COMPOSER_PACKAGES}

COPY etc/ /etc/

WORKDIR /var/www
# user nobody, group www-data
USER ${UID}:${GID}

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 8080

ENTRYPOINT ["/etc/init.d/rc.local"]
