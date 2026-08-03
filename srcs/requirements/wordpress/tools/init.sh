#!/bin/sh
set -eu

WORDPRESS_DIRECTORY=/var/www/html
WORDPRESS_SOURCE=/usr/src/wordpress

DATABASE_PASSWORD=$(cat /run/secrets/db_password)
ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
USER_PASSWORD=$(cat /run/secrets/wp_user_password)

case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in
    *admin*)
        echo "The administrator username must not contain 'admin'." >&2
        exit 1
        ;;
esac

cd "$WORDPRESS_DIRECTORY"

if [ ! -f wp-includes/version.php ]; then
    cp -a "$WORDPRESS_SOURCE"/. "$WORDPRESS_DIRECTORY"/
fi

if [ ! -f wp-config.php ]; then
    wp config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$DATABASE_PASSWORD" \
        --dbhost=mariadb:3306 \
        --allow-root
fi

if ! wp core is-installed --allow-root; then
    wp core install \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root
fi

if ! wp user get "$WP_USER" --allow-root >/dev/null 2>&1; then
    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --user_pass="$USER_PASSWORD" \
        --role=author \
        --allow-root
fi

chown -R www-data:www-data "$WORDPRESS_DIRECTORY"

exec php-fpm8.2 --nodaemonize
