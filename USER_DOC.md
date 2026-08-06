# Inception User Documentation

## Services provided

The stack provides a WordPress website over HTTPS.

- **NGINX** receives browser requests on port `443` and provides TLS encryption.
- **WordPress with PHP-FPM** runs the website and the administration panel.
- **MariaDB** stores WordPress users, posts, pages, comments, and settings.

Only NGINX is directly accessible from the host. WordPress and MariaDB communicate internally through the Docker network.

> **Important**
>
> The repository intentionally excludes `srcs/.env` and all secret files.
> They must be created locally before the first build.

## First-time setup

### 1. Create the local `.env` file

Create the following file:

```text
srcs/.env
```

It must contain the project-specific, non-password configuration expected by the Makefile and `srcs/docker-compose.yml`.

The exact values depend on the learner and local machine, so they are intentionally not included in this document.

Do not commit this file:

```sh
git check-ignore -v srcs/.env
```

### 2. Configure the domain

Add the following line to `/etc/hosts` inside the virtual machine:

```text
127.0.0.1 <login>.42.fr
```

When opening the site from another computer, use the virtual machine's reachable IP address instead of `127.0.0.1`.

### 3. Create local credentials

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

Confirm that the local configuration and credentials are ignored:

```sh
git status
git check-ignore -v srcs/.env
git check-ignore -v secrets/db_password.txt
```

## Start the project

From the repository root:

```sh
make
```

The first build can take several minutes because Docker must download Debian packages and build all three images.

## Access the website

Open:

```text
https://<login>.42.fr
```

The TLS certificate is self-signed. A browser warning is expected; continue only when the certificate belongs to the local project domain.

## Access the administration panel

Open:

```text
https://<login>.42.fr/wp-admin
```

Use the local WordPress account information configured for the project.

The WordPress account passwords are stored locally in:

```text
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

The usernames are part of the local project configuration and are intentionally not reproduced in this document.

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

The `mariadb`, `wordpress`, and `nginx` containers should be running. MariaDB may also report a healthy status if a health check is configured.

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
curl -kI https://<login>.42.fr
```

Confirm that HTTP port `80` is not published:

```sh
curl -I http://<login>.42.fr
```

Confirm that only NGINX publishes a host port:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
```

## Credential management

The project requires two types of local files:

- `srcs/.env` for project-specific, non-password configuration.
- files under `secrets/` for confidential passwords.

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

The WordPress initialization script synchronizes the stored WordPress account password with the mounted secret when the container starts.

Changing MariaDB passwords after the database has already been initialized requires updating the existing database accounts as well. Simply changing a MariaDB secret file does not automatically change an existing database password.

## Persistent data

The project stores persistent data on the host in:

```text
/home/<login>/data/mariadb
/home/<login>/data/wordpress
```

Stopping or recreating containers does not remove these files. `make fclean` and `make reset` remove them.
