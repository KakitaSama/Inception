#!/bin/sh
set -eu

DATA_DIRECTORY=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock
INITIALIZED_FILE="$DATA_DIRECTORY/.inception_initialized"

ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DATABASE_PASSWORD=$(cat /run/secrets/db_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld "$DATA_DIRECTORY"

if [ ! -d "$DATA_DIRECTORY/mysql" ]; then
    mariadb-install-db \
        --user=mysql \
        --datadir="$DATA_DIRECTORY" \
        --skip-test-db
fi

if [ ! -f "$INITIALIZED_FILE" ]; then
    mariadbd \
        --user=mysql \
        --skip-networking \
        --socket="$SOCKET" &

    temporary_server_pid=$!

    attempts=30
    until mariadb-admin --socket="$SOCKET" ping --silent; do
        kill -0 "$temporary_server_pid"

        attempts=$((attempts - 1))
        [ "$attempts" -gt 0 ] || exit 1

        sleep 1
    done

    mariadb --socket="$SOCKET" <<SQL
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$DATABASE_PASSWORD';
ALTER USER '$MYSQL_USER'@'%' IDENTIFIED BY '$DATABASE_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';
FLUSH PRIVILEGES;
SQL

    mariadb-admin \
        --socket="$SOCKET" \
        --user=root \
        --password="$ROOT_PASSWORD" \
        shutdown

    wait "$temporary_server_pid"
    touch "$INITIALIZED_FILE"
    chown mysql:mysql "$INITIALIZED_FILE"
fi

exec mariadbd \
    --user=mysql \
    --bind-address=0.0.0.0
