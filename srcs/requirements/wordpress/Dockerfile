FROM debian:bookworm

ARG WORDPRESS_VERSION=7.0.2
ARG WP_CLI_VERSION=2.12.0

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        mariadb-client \
        php-cli \
        php-curl \
        php-fpm \
        php-gd \
        php-mbstring \
        php-mysql \
        php-xml \
        php-zip \
    && curl --fail --silent --show-error --location \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
        --output /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp \
    && mkdir -p /usr/src/wordpress \
    && mkdir -p /run/php \
    && wp core download \
        --version="${WORDPRESS_VERSION}" \
        --path=/usr/src/wordpress \
        --allow-root \
    && sed -i \
        's|^listen = .*|listen = 9000|' \
        /etc/php/8.2/fpm/pool.d/www.conf \
    && rm -rf /var/lib/apt/lists/*

COPY tools/init.sh /usr/local/bin/wordpress-init

RUN chmod +x /usr/local/bin/wordpress-init

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wordpress-init"]
