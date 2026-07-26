#!/bin/sh
set -eu

WP_PATH=/var/www/html
WP_SOURCE=/usr/src/wordpress

RUN_DIR=/run/wordpress
MYSQL_CNF="$RUN_DIR/mariadb-client.cnf"

DB_SECRET=/run/secrets/db_password
WP_ADMIN_SECRET=/run/secrets/wp_admin_password
WP_USER_SECRET=/run/secrets/wp_user_password

log()
{
    printf '%s\n' "[wordpress-entrypoint] $*"
}

die()
{
    printf '%s\n' "[wordpress-entrypoint] ERROR: $*" >&2
    exit 1
}

cleanup()
{
    rm -f "$MYSQL_CNF"
}

wp_cli()
{
    runuser -u www-data -- \
        env \
            HOME=/tmp \
            WP_CLI_CACHE_DIR=/tmp/wp-cli-cache \
        wp \
            --path="$WP_PATH" \
            --no-color \
            "$@"
}

trap cleanup EXIT INT TERM HUP

# Permit utility commands such as:
# docker run --rm wordpress:1.0 php --version
if [ "$#" -eq 0 ]; then
    set -- php-fpm8.2 -F
fi

if [ "$1" != "php-fpm8.2" ]; then
    trap - EXIT INT TERM HUP
    exec "$@"
fi

# Required non-secret configuration.
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
: "${MYSQL_HOST:?MYSQL_HOST is required}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

: "${WP_TITLE:?WP_TITLE is required}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is required}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is required}"
: "${WP_USER:?WP_USER is required}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL is required}"

# The database identifiers are later used by WordPress configuration.
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

case "$WP_ADMIN_USER" in
    *[!A-Za-z0-9_.-]*|'')
        die "WP_ADMIN_USER contains unsupported characters"
        ;;
esac

case "$WP_USER" in
    *[!A-Za-z0-9_.-]*|'')
        die "WP_USER contains unsupported characters"
        ;;
esac

if [ "$WP_ADMIN_USER" = "$WP_USER" ]; then
    die "The administrator and normal WordPress user must be different"
fi

LOWER_ADMIN=$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')

case "$LOWER_ADMIN" in
    *admin*)
        die "The administrator username must not contain admin"
        ;;
esac

# Required secrets.
[ -r "$DB_SECRET" ] ||
    die "Missing readable secret: $DB_SECRET"

[ -r "$WP_ADMIN_SECRET" ] ||
    die "Missing readable secret: $WP_ADMIN_SECRET"

[ -r "$WP_USER_SECRET" ] ||
    die "Missing readable secret: $WP_USER_SECRET"

DB_PASSWORD=$(cat "$DB_SECRET")

case "$DB_PASSWORD" in
    *[!A-Za-z0-9_-]*|'')
        die "db_password must use only the expected URL-safe characters"
        ;;
esac

mkdir -p \
    "$WP_PATH" \
    /run/php \
    "$RUN_DIR" \
    /tmp/wp-cli-cache

chown -R www-data:www-data \
    "$WP_PATH" \
    /tmp/wp-cli-cache

# Store temporary client credentials outside the WordPress volume.
umask 077

cat > "$MYSQL_CNF" <<EOF_CNF
[client]
protocol=tcp
host=$MYSQL_HOST
port=3306
user=$MYSQL_USER
password=$DB_PASSWORD
EOF_CNF

# The bind-backed named volume begins empty.
# Copy the immutable WordPress source from the image into the volume.
if [ ! -f "$WP_PATH/wp-includes/version.php" ]; then
    log "Copying WordPress core into the persistent volume"

    cp -a "$WP_SOURCE/." "$WP_PATH/"
fi

chown -R www-data:www-data "$WP_PATH"

# Wait for MariaDB with a bounded retry.
log "Waiting for MariaDB"

attempt=1
database_ready=0

while [ "$attempt" -le 60 ]; do
    if mariadb-admin \
        --defaults-extra-file="$MYSQL_CNF" \
        ping --silent >/dev/null 2>&1
    then
        database_ready=1
        break
    fi

    log "MariaDB is not ready yet: attempt $attempt/60"

    sleep 1
    attempt=$((attempt + 1))
done

[ "$database_ready" -eq 1 ] ||
    die "MariaDB did not become ready after 60 attempts"

log "MariaDB is ready"

# Create wp-config.php only when it does not already exist.
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    log "Generating wp-config.php"

    wp_cli config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbhost="$MYSQL_HOST:3306" \
        --dbprefix="wp_" \
        --dbcharset="utf8mb4" \
        --skip-salts \
        --prompt=dbpass \
        < "$DB_SECRET"

    # Generate salts locally so startup does not depend on an external API.
    for key in \
        AUTH_KEY \
        SECURE_AUTH_KEY \
        LOGGED_IN_KEY \
        NONCE_KEY \
        AUTH_SALT \
        SECURE_AUTH_SALT \
        LOGGED_IN_SALT \
        NONCE_SALT
    do
        value=$(php -r 'echo bin2hex(random_bytes(32));')

        wp_cli config set "$key" "$value"
    done

    wp_cli config set WP_HOME "https://$DOMAIN_NAME"
    wp_cli config set WP_SITEURL "https://$DOMAIN_NAME"
    wp_cli config set FS_METHOD "direct"
    wp_cli config set WP_DEBUG false --raw

    chmod 640 "$WP_PATH/wp-config.php"
    chown www-data:www-data "$WP_PATH/wp-config.php"
fi

# Install WordPress only when its database tables do not exist.
if ! wp_cli core is-installed >/dev/null 2>&1; then
    log "Installing WordPress"

    wp_cli core install \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --prompt=admin_password \
        < "$WP_ADMIN_SECRET"
else
    log "Existing WordPress database installation detected"
fi

# Create the required non-administrator account only once.
if ! wp_cli user get "$WP_USER" --field=ID >/dev/null 2>&1; then
    log "Creating the normal WordPress user"

    wp_cli user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --role=subscriber \
        --prompt=user_pass \
        < "$WP_USER_SECRET"
else
    log "Normal WordPress user already exists"
fi

chown -R www-data:www-data "$WP_PATH"

cleanup
trap - EXIT INT TERM HUP

log "Starting PHP-FPM as the container main process"

exec "$@"
