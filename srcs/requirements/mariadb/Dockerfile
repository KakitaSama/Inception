FROM debian:bookworm

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        mariadb-server \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql/*

COPY tools/init.sh /usr/local/bin/mariadb-init

RUN chmod +x /usr/local/bin/mariadb-init

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/mariadb-init"]
