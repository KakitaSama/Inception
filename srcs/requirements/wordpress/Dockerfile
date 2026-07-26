FROM debian:12

ARG WORDPRESS_VERSION=7.0.2
ARG WP_CLI_VERSION=2.12.0

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        ca-certificates \
        curl \
        mariadb-client \
        php8.2-cli \
        php8.2-curl \
        php8.2-fpm \
        php8.2-gd \
        php8.2-intl \
        php8.2-mbstring \
        php8.2-mysql \
        php8.2-xml \
        php8.2-zip \
        unzip \
        util-linux \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/wordpress \
    && curl -fsSL \
        "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" \
        -o /tmp/wordpress.tar.gz \
    && tar -xzf /tmp/wordpress.tar.gz \
        --strip-components=1 \
        -C /usr/src/wordpress \
    && rm -f /tmp/wordpress.tar.gz

RUN curl -fsSL \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
        -o /usr/local/bin/wp \
    && chmod 755 /usr/local/bin/wp \
    && wp --allow-root --info

COPY conf/php-fpm.conf \
    /etc/php/8.2/fpm/php-fpm.conf

COPY conf/www.conf \
    /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/entrypoint.sh \
    /usr/local/bin/wordpress-entrypoint

RUN mkdir -p \
        /var/www/html \
        /run/php \
        /run/wordpress \
        /tmp/wp-cli-cache \
    && chown -R www-data:www-data \
        /var/www/html \
        /tmp/wp-cli-cache \
    && chmod 755 /usr/local/bin/wordpress-entrypoint

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint"]

CMD ["php-fpm8.2", "-F"]
