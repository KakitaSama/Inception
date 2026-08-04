FROM debian:bookworm

ARG WP_CLI_VERSION=2.12.0

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl php-cli php-fpm php-mysql \
    && curl -L  "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp \
    && mkdir -p /usr/src/wordpress /run/php \
    && cd /usr/src/wordpress \
    && wp core download --allow-root \
    && sed -i 's|^listen = .*|listen = 9000|' /etc/php/8.2/fpm/pool.d/www.conf \
    && rm -rf /var/lib/apt/lists/*

COPY tools/init.sh /usr/local/bin/wordpress-init

RUN chmod +x /usr/local/bin/wordpress-init

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wordpress-init"]
