FROM alpine:3.14

ARG ALPINE_PACKAGES="php8-pdo_mysql php8-pdo_pgsql php8-openssl"
ARG COMPOSER_PACKAGES=google/cloud-storage
ARG PBURL=https://github.com/PrivateBin/PrivateBin/
ARG RELEASE=1.3.5

ENV CONFIG_PATH=/srv/cfg

LABEL org.opencontainers.image.authors=support@privatebin.org \
      org.opencontainers.image.vendor=PrivateBin \
      org.opencontainers.image.documentation=https://github.com/PrivateBin/docker-nginx-fpm-alpine/blob/master/README.md \
      org.opencontainers.image.source=https://github.com/PrivateBin/docker-nginx-fpm-alpine \
      org.opencontainers.image.licenses=zlib-acknowledgement \
      org.opencontainers.image.version=${RELEASE}

RUN \
# Prepare composer dependencies
    ALPINE_PACKAGES="$(echo ${ALPINE_PACKAGES} | sed 's/,/ /g')" ;\
    ALPINE_COMPOSER_PACKAGES="" ;\
    if [ -n "${COMPOSER_PACKAGES}" ] ; then \
        ALPINE_COMPOSER_PACKAGES="php8 php8-curl php8-mbstring php8-phar" ;\
        RAWURL="$(echo ${PBURL} | sed s/github.com/raw.githubusercontent.com/)" ;\
    fi \
# Install dependencies
    && apk upgrade --no-cache \
    && apk add --no-cache gnupg git nginx php8-fpm php8-json php8-gd php8-opcache \
        s6-linux-init s6-rc tzdata ${ALPINE_PACKAGES} ${ALPINE_COMPOSER_PACKAGES} \
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
    && if [ -n "${COMPOSER_PACKAGES}" ] ; then \
        wget -qO composer-installer.php https://getcomposer.org/installer \
        && ln -s $(which php8) /usr/local/bin/php \
        && php composer-installer.php --install-dir=/usr/local/bin --filename=composer ;\
    fi \
    && cd /var/www \
    && tar -xzf /tmp/${RELEASE}.tar.gz --strip 1 \
    && if [ -n "${COMPOSER_PACKAGES}" ] ; then \
        wget -q ${RAWURL}${RELEASE}/composer.json \
        && wget -q ${RAWURL}${RELEASE}/composer.lock \
        && composer remove --dev --no-update phpunit/phpunit \
        && composer require --no-update ${COMPOSER_PACKAGES} \
        && composer update --no-dev --optimize-autoloader \
        rm composer.* /usr/local/bin/* ;\
    fi \
    && rm *.md cfg/conf.sample.php \
    && mv cfg lib tpl vendor /srv \
    && mkdir -p /srv/data \
    && sed -i "s#define('PATH', '');#define('PATH', '/srv/');#" index.php \
# Support running s6 under a non-root user
    && mkdir -p /etc/s6/services/nginx/supervise /etc/s6/services/php-fpm8/supervise /etc/s6-rc \
    && mkfifo \
        /etc/s6/services/nginx/supervise/control \
        /etc/s6/services/php-fpm8/supervise/control \
    && chown -R 65534:82 /etc/s6 /run /srv/* /var/lib/nginx /var/www \
    && chmod o+rwx /run /var/lib/nginx /var/lib/nginx/tmp /usr/bin/s6-linux-init* \
# Clean up
    && rm -rf "${GNUPGHOME}" /tmp/* \
    && apk del --no-cache gnupg git ${ALPINE_COMPOSER_PACKAGES}

COPY etc/ /etc/

RUN s6-rc-compile /etc/s6-rc/compiled /etc/s6/services \
    && s6-linux-init-maker -C -N -B /etc/s6-linux-init/current

WORKDIR /var/www
# user nobody, group www-data
USER 65534:82

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 8080

ENTRYPOINT ["/etc/s6-linux-init/current/bin/init"]
