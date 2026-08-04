#!/bin/sh

set -e


DB_PASSWORD=$(cat /run/secrets/db_password)
ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
USER_PASSWORD=$(cat /run/secrets/wp_user_password)

cd /var/www/html

if [ ! -f wp-settings.php ]; then
    cp -a /usr/src/wordpress/. .
fi

if [ ! -f wp-config.php ]; then
    wp config create  --dbname="$MYSQL_DATABASE"  --dbuser="$MYSQL_USER"   --dbpass="$DB_PASSWORD"  --dbhost=mariadb --allow-root
fi

if ! wp core is-installed --allow-root; then
    wp core install  --url="https://$DOMAIN_NAME" --title="$WP_TITLE"  --admin_user="$WP_ADMIN_USER"  --admin_password="$ADMIN_PASSWORD"  --admin_email="$WP_ADMIN_EMAIL" --allow-root
fi

wp user update "$WP_ADMIN_USER" --user_pass="$ADMIN_PASSWORD" --allow-root

if wp user get "$WP_USER" --allow-root ; then
    wp user update "$WP_USER" --user_pass="$USER_PASSWORD" --allow-root
else
    wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$USER_PASSWORD" --allow-root 
fi

chown -R www-data:www-data /var/www/html

exec php-fpm8.2 -F