#!/bin/sh
set -eu

DATADIR=/var/lib/mysql
RUNDIR=/run/mysqld
SOCKET="$RUNDIR/mysqld.sock"
PID_FILE="$RUNDIR/mysqld.pid"

MARKER="$DATADIR/.inception_initialized"

ROOT_SECRET=/run/secrets/db_root_password
DB_SECRET=/run/secrets/db_password
ROOT_CNF="$RUNDIR/root-client.cnf"

TEMP_PID=""

log()
{
    printf '%s\n' "[mariadb-entrypoint] $*"
}

die()
{
    printf '%s\n' "[mariadb-entrypoint] ERROR: $*" >&2
    exit 1
}

cleanup()
{
    rm -f "$ROOT_CNF"

    if [ -n "$TEMP_PID" ] && kill -0 "$TEMP_PID" 2>/dev/null; then
        log "Stopping temporary MariaDB server"
        kill -TERM "$TEMP_PID" 2>/dev/null || true
        wait "$TEMP_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM HUP

# Allow the image to execute utility commands such as:
# docker run mariadb:1.0 mariadb --version
if [ "$#" -eq 0 ]; then
    set -- mariadbd --user=mysql
fi

if [ "$1" != "mariadbd" ]; then
    trap - EXIT INT TERM HUP
    exec "$@"
fi

# Required non-secret configuration.
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

# Database and account names will be inserted as SQL identifiers.
case "$MYSQL_DATABASE" in
    *[!A-Za-z0-9_]*|'')
        die "MYSQL_DATABASE may contain only letters, digits, and underscores"
        ;;
esac

case "$MYSQL_USER" in
    *[!A-Za-z0-9_]*|'')
        die "MYSQL_USER may contain only letters, digits, and underscores"
        ;;
esac

# Required secrets.
[ -r "$ROOT_SECRET" ] ||
    die "Missing readable secret: $ROOT_SECRET"

[ -r "$DB_SECRET" ] ||
    die "Missing readable secret: $DB_SECRET"

DB_ROOT_PASSWORD=$(cat "$ROOT_SECRET")
DB_PASSWORD=$(cat "$DB_SECRET")

# These rules match the token_urlsafe secrets generated for this project.
case "$DB_ROOT_PASSWORD" in
    *[!A-Za-z0-9_-]*|'')
        die "db_root_password must use only URL-safe characters"
        ;;
esac

case "$DB_PASSWORD" in
    *[!A-Za-z0-9_-]*|'')
        die "db_password must use only URL-safe characters"
        ;;
esac

# /var/lib/mysql is a mounted host-backed named volume.
# Its ownership may not match the mysql service user at container creation.
mkdir -p "$DATADIR" "$RUNDIR"
chown -R mysql:mysql "$DATADIR" "$RUNDIR"
chmod 750 "$DATADIR" "$RUNDIR"

if [ ! -f "$MARKER" ]; then
    if [ ! -d "$DATADIR/mysql" ]; then
        log "Initializing MariaDB system tables"

        mariadb-install-db \
            --user=mysql \
            --datadir="$DATADIR" \
            --skip-test-db
    else
        log "System tables exist but initialization marker is missing; resuming setup"
    fi

    log "Starting temporary MariaDB server with networking disabled"

    mariadbd \
        --user=mysql \
        --skip-networking \
        --socket="$SOCKET" \
        --pid-file="$PID_FILE" &

    TEMP_PID=$!

    ready=0
    attempt=1

    while [ "$attempt" -le 30 ]; do
        if mariadb-admin \
            --protocol=socket \
            --socket="$SOCKET" \
            ping --silent >/dev/null 2>&1
        then
            ready=1
            break
        fi

        if ! kill -0 "$TEMP_PID" 2>/dev/null; then
            wait "$TEMP_PID" || true
            die "Temporary MariaDB server exited before becoming ready"
        fi

        sleep 1
        attempt=$((attempt + 1))
    done

    [ "$ready" -eq 1 ] ||
        die "Temporary MariaDB server was not ready after 30 attempts"

    root_mode=""

    # On the first run, mariadb-install-db normally creates root@localhost
    # with Unix-socket authentication.
    if mariadb \
        --protocol=socket \
        --socket="$SOCKET" \
        -uroot \
        -e 'SELECT 1' >/dev/null 2>&1
    then
        root_mode="socket"
    else
        # This path allows recovery if initialization was interrupted after
        # the root password had already been configured.
        umask 077

        cat > "$ROOT_CNF" <<EOF_CNF
[client]
user=root
password=$DB_ROOT_PASSWORD
protocol=socket
socket=$SOCKET
EOF_CNF

        if mariadb \
            --defaults-extra-file="$ROOT_CNF" \
            -e 'SELECT 1' >/dev/null 2>&1
        then
            root_mode="password"
        else
            die "Cannot authenticate as MariaDB root to complete initialization"
        fi
    fi

    log "Creating the application database and restricted account"

    if [ "$root_mode" = "socket" ]; then
        mariadb \
            --protocol=socket \
            --socket="$SOCKET" \
            -uroot <<EOF_SQL
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%';

ALTER USER '$MYSQL_USER'@'%'
    IDENTIFIED BY '$DB_PASSWORD';

GRANT ALL PRIVILEGES
    ON \`$MYSQL_DATABASE\`.*
    TO '$MYSQL_USER'@'%';

ALTER USER 'root'@'localhost'
    IDENTIFIED VIA mysql_native_password
    USING PASSWORD('$DB_ROOT_PASSWORD');

SHUTDOWN;
EOF_SQL
    else
        mariadb \
            --defaults-extra-file="$ROOT_CNF" <<EOF_SQL
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%';

ALTER USER '$MYSQL_USER'@'%'
    IDENTIFIED BY '$DB_PASSWORD';

GRANT ALL PRIVILEGES
    ON \`$MYSQL_DATABASE\`.*
    TO '$MYSQL_USER'@'%';

ALTER USER 'root'@'localhost'
    IDENTIFIED VIA mysql_native_password
    USING PASSWORD('$DB_ROOT_PASSWORD');

SHUTDOWN;
EOF_SQL
    fi

    wait "$TEMP_PID"
    TEMP_PID=""

    touch "$MARKER"
    chown mysql:mysql "$MARKER"
    chmod 600 "$MARKER"

    rm -f "$ROOT_CNF"

    log "MariaDB initialization completed"
else
    log "Existing initialized data directory detected; skipping initialization"
fi

trap - EXIT INT TERM HUP

log "Starting MariaDB as the container main process"
exec "$@"
