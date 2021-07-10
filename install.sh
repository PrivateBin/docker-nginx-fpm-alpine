#!/bin/sh
set -e -u -x


export GNUPGHOME="$(mktemp -d)"

main() {
    alpine_packages=""
    composer_packages=""

    while getopts "p:c:r:" arg; do
      case $arg in
	r)
	  RELEASE=$OPTARG
	  ;;
	p)
	  alpine_packages="$alpine_packages $OPTARG"
	  ;;
	c)
	  composer_packages="$composer_packages $OPTARG"
	  ;;
        *)
         echo "[-p alpine-package] [-c composer-package] ...">&2 && exit 1;;
      esac
    done
    export RELEASE

    add_packages $alpine_packages
    download_privatebin
    composer_update $composer_packages
    configure_nginx
    configure_privatebin
    configure_s6
    cleanup

}

add_packages() {
    apk add --no-cache gnupg nginx php8 php8-curl php8-fpm php8-json php8-gd \
	    php8-mbstring php8-opcache php8-phar \
	    s6-overlay tzdata git php8-openssl $@
    apk upgrade --no-cache
}

configure_nginx() {
    # Remove (some of the) default nginx config
    rm -f /etc/nginx.conf /etc/nginx/http.d/default.conf /etc/php8/php-fpm.d/www.conf
    rm -rf /etc/nginx/sites-*
    # Ensure nginx logs, even if the config has errors, are written to stderr
    ln -s /dev/stderr /var/lib/nginx/logs/error.log
}

download_privatebin() {
    (
	gpg2 --list-public-keys || /bin/true
	wget -qO - https://privatebin.info/key/release.asc | gpg2 --import -
        mkdir -p /var/www && rm -rf /var/www/*

	cd /tmp
	if expr "${RELEASE}" : '[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}$' >/dev/null ; then
	    echo "getting release ${RELEASE}";
	    wget -qO ${RELEASE}.tar.gz.asc ${PBURL}releases/download/${RELEASE}/PrivateBin-${RELEASE}.tar.gz.asc
	    wget -q ${PBURL}archive/${RELEASE}.tar.gz
	    gpg2 --verify ${RELEASE}.tar.gz.asc ;
	else
	    echo "getting tarball for ${RELEASE}";
	    git clone ${PBURL%%/}.git -b ${RELEASE};
	    (cd $(basename ${PBURL}) && git archive --prefix ${RELEASE}/ --format tgz ${RELEASE} > /tmp/${RELEASE}.tar.gz);
	fi
	tar -C /var/www -xzf /tmp/${RELEASE}.tar.gz --strip 1
    )
}

composer_update() {
    (
	cd /var/www
	wget -qO composer-setup.php https://getcomposer.org/installer
	ln -s $(which php8) /usr/local/bin/php
	/usr/local/bin/php composer-setup.php --install-dir=/usr/local/bin --filename=composer
	wget -q $(echo ${PBURL} | sed s/github.com/raw.githubusercontent.com/)${RELEASE}/composer.json
	wget -q $(echo ${PBURL} | sed s/github.com/raw.githubusercontent.com/)${RELEASE}/composer.lock
	composer remove --dev --no-update phpunit/phpunit
	[ -z "$@" ] || composer require --no-update $@
	composer update --no-dev --optimize-autoloader
    )
}

configure_privatebin() {
    (
	cd /var/www
	rm *.md cfg/conf.sample.php composer.* composer-setup.php /usr/local/bin/*
	mkdir -p /srv/data
	mv cfg lib tpl vendor /srv
	sed -i "s#define('PATH', '');#define('PATH', '/srv/');#" index.php
    )
}


configure_s6() {
    # Support running s6 under a non-root user
    mkdir -p /etc/s6/services/nginx/supervise /etc/s6/services/php-fpm8/supervise
    mkfifo /etc/s6/services/nginx/supervise/control /etc/s6/services/php-fpm8/supervise/control
    chown -R 65534:82 /etc/s6 /run /srv/* /var/lib/nginx /var/www
    chmod o+rwx /run /var/lib/nginx /var/lib/nginx/tmp
}

cleanup() {
    rm -rf "${GNUPGHOME}" /tmp/*
    apk del gnupg php8 php8-curl php8-mbstring php8-phar git
}

main "$@"
