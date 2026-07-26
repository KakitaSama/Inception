FROM debian:12

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        mariadb-server \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/*

COPY conf/50-server.cnf \
    /etc/mysql/mariadb.conf.d/50-server.cnf

COPY tools/entrypoint.sh \
    /usr/local/bin/mariadb-entrypoint

RUN rm -rf /var/lib/mysql/* \
    && mkdir -p /var/lib/mysql /run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /run/mysqld \
    && chmod 755 /usr/local/bin/mariadb-entrypoint

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/mariadb-entrypoint"]

CMD ["mariadbd", "--user=mysql"]
