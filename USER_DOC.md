# Inception User Documentation

## Services provided

The stack provides a WordPress website over HTTPS.

- **NGINX** receives browser requests on port `443` and provides TLS encryption.
- **WordPress with PHP-FPM** runs the website and the administration panel.
- **MariaDB** stores WordPress users, posts, pages, comments, and settings.

Only NGINX is directly accessible from the host. WordPress and MariaDB communicate internally through the Docker network.

## First-time setup

### 1. Configure the domain

Add the following line to `/etc/hosts` inside the virtual machine:

```text
127.0.0.1 sel-jazo.42.fr
```

When opening the site from another computer, use the virtual machine's IP address instead of `127.0.0.1`.

### 2. Create local credentials

From the project root:

```sh
mkdir -p secrets
openssl rand -hex 24 > secrets/db_root_password.txt
openssl rand -hex 24 > secrets/db_password.txt
openssl rand -hex 24 > secrets/wp_admin_password.txt
openssl rand -hex 24 > secrets/wp_user_password.txt
chmod 600 secrets/*.txt
```

Do not commit these files to Git.

## Start the project

From the repository root:

```sh
make
```

The first build can take several minutes because Docker must download Debian packages and build all three images.

## Access the website

Open:

```text
https://sel-jazo.42.fr
```

The TLS certificate is self-signed. A browser warning is expected; continue only when the certificate belongs to the local project domain.

## Access the administration panel

Open:

```text
https://sel-jazo.42.fr/wp-admin
```

The administrator username is stored in:

```text
srcs/.env
```

under:

```text
WP_ADMIN_USER
```

The administrator password is stored locally in:

```text
secrets/wp_admin_password.txt
```

The normal WordPress username is stored in `WP_USER` inside `srcs/.env`, and its password is stored in `secrets/wp_user_password.txt`.

## Stop and restart

Stop the containers without deleting persistent data:

```sh
make down
```

Rebuild and restart the project:

```sh
make re
```

Perform a complete reset, delete persistent data, and build again:

```sh
make reset
```

A complete reset deletes the WordPress website and database. Back up important data before using it.

## Check that services are running

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
```

The `mariadb`, `wordpress`, and `nginx` containers should be running. MariaDB should also report a healthy status.

View logs from every service:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs
```

Follow logs continuously:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs -f
```

View one service only:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs nginx
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs wordpress
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs mariadb
```

## Basic verification

Confirm that HTTPS works:

```sh
curl -kI https://sel-jazo.42.fr
```

Confirm that HTTP port `80` is not published:

```sh
curl -I http://sel-jazo.42.fr
```

Confirm that only NGINX publishes a host port:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
```

## Credential management

The non-confidential configuration is stored in `srcs/.env`.

The confidential files are:

```text
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

To change a WordPress password, replace the corresponding secret file and restart the WordPress container:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml restart wordpress
```

The WordPress initialization script synchronizes the stored WordPress account password with the secret when the container starts.

Changing the MariaDB passwords after the database has already been initialized requires updating the database accounts as well. Simply changing a MariaDB secret file does not automatically change an existing database password.

## Persistent data

The project stores persistent data on the host in:

```text
/home/sel-jazo/data/mariadb
/home/sel-jazo/data/wordpress
```

Stopping or recreating containers does not remove these files. `make fclean` and `make reset` remove them.
