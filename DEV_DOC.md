# Inception Developer Documentation

## Overview

The project is managed by Docker Compose and contains three custom images:

| Service | Main process | Internal port | Host port |
|---|---|---:|---:|
| `mariadb` | `mariadbd` | `3306` | none |
| `wordpress` | `php-fpm8.2 -F` | `9000` | none |
| `nginx` | `nginx -g 'daemon off;'` | `443` | `443` |

The containers share the `inception` bridge network. Docker's internal DNS resolves service names such as `mariadb` and `wordpress`.

> **Local-only files**
>
> The repository intentionally excludes `srcs/.env` and the password files under `secrets/`.
> These files must be created locally before building the stack.

## Repository structure

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   └── .gitkeep
└── srcs/
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf
        │   └── tools/init.sh
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/default
        └── wordpress/
            ├── Dockerfile
            └── tools/init.sh
```

At runtime, a local `srcs/.env` file must also exist. It is intentionally not committed.

## Prerequisites

Install inside the virtual machine:

- Docker Engine
- Docker Compose v2
- GNU Make
- OpenSSL

Verify the installation:

```sh
docker --version
docker compose version
make --version
openssl version
```

The Docker daemon must be running, and the current user must be allowed to use Docker.

## Environment configuration

Create `srcs/.env` locally before building the project.

The file contains the project-specific, non-password values expected by:

- the Makefile;
- `srcs/docker-compose.yml`;
- the service build arguments and runtime environment.

Its exact values depend on the learner and machine and are intentionally not reproduced here.

Passwords must never be placed in `.env`.

Confirm that the file is ignored by Git:

```sh
git check-ignore -v srcs/.env
```

## Secret configuration

Create the required local secret files:

```sh
mkdir -p secrets
openssl rand -hex 24 > secrets/db_root_password.txt
openssl rand -hex 24 > secrets/db_password.txt
openssl rand -hex 24 > secrets/wp_admin_password.txt
openssl rand -hex 24 > secrets/wp_user_password.txt
chmod 600 secrets/*.txt
```

Confirm before committing:

```sh
git status
git check-ignore -v srcs/.env
git check-ignore -v secrets/db_password.txt
```

No password should appear in a Dockerfile, `docker-compose.yml`, `.env`, README, documentation, or Git history.

## Build and launch

From the repository root:

```sh
make
```

The Makefile creates the host data directories and executes Docker Compose with the local `.env` file.

Equivalent command:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up --detach --build
```

Check the result:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs
```

## Service implementation

### MariaDB

The MariaDB image installs `mariadb-server` and `mariadb-client` from Debian.

Its initialization script:

1. Reads the database passwords from `/run/secrets`.
2. Creates and owns `/run/mysqld` and `/var/lib/mysql` for the `mysql` user.
3. Detects first initialization by checking `/var/lib/mysql/mysql`.
4. Initializes the system tables with `mariadb-install-db`.
5. Uses MariaDB bootstrap mode to create the WordPress database, database user, grants, and root password.
6. Replaces the shell process with `mariadbd` using `exec`.

`50-server.cnf` makes MariaDB listen on the container network so WordPress can reach it through the Docker bridge network.

### WordPress and PHP-FPM

The WordPress image installs PHP CLI, PHP-FPM, the PHP MySQL extension, Curl, CA certificates, WP-CLI, and WordPress core.

The PHP-FPM pool listens on TCP port `9000`:

```ini
listen = 9000
```

Its initialization script:

1. Reads database and WordPress passwords from `/run/secrets`.
2. Copies WordPress core files into the persistent volume when they are absent.
3. Creates `wp-config.php` when it is absent.
4. Configures the WordPress URL.
5. Installs WordPress when the database does not yet contain an installation.
6. Creates or updates the required WordPress users.
7. Synchronizes their passwords with the mounted secrets.
8. Replaces the shell process with PHP-FPM in foreground mode.

### NGINX

The NGINX image installs NGINX and OpenSSL.

During the image build it:

1. Configures the project domain.
2. Generates a self-signed certificate and private key.
3. Adds the configured domain to the certificate.

NGINX accepts TLS 1.2 and TLS 1.3 only and forwards PHP requests to:

```nginx
fastcgi_pass wordpress:9000;
```

It shares the WordPress volume as read-only so it can serve static files while PHP execution remains in the WordPress container.

## Networking

Inspect the network:

```sh
docker network ls
docker network inspect inception
```

Test service-name resolution from NGINX:

```sh
docker exec nginx getent hosts wordpress
```

Test service-name resolution from WordPress:

```sh
docker exec wordpress getent hosts mariadb
```

Only NGINX should publish a host port:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
```

## Volumes and persistence

List and inspect the named volumes:

```sh
docker volume ls
docker volume inspect mariadb_data
docker volume inspect wordpress_data
```

The volume configuration stores data under:

```text
/home/<login>/data/mariadb
/home/<login>/data/wordpress
```

Inspect the host data:

```sh
sudo ls -la /home/<login>/data/mariadb
sudo ls -la /home/<login>/data/wordpress
```

`make down` removes containers and the Compose network but preserves the named volumes and host data.

`make fclean` removes the Compose volumes and deletes both host data directories. This permanently deletes the database and website files.

## Container and Compose management

Start or rebuild:

```sh
make
```

Stop without deleting data:

```sh
make down
```

Stop and start again:

```sh
make re
```

Delete all project data and rebuild:

```sh
make reset
```

Open a shell in a running container:

```sh
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh
```

Follow logs:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs -f
```

## Database inspection

Open a MariaDB client inside the MariaDB container:

```sh
docker exec -it mariadb sh
mariadb -u root -p
```

Enter the local root password from:

```text
secrets/db_root_password.txt
```

Useful SQL checks:

```sql
SHOW DATABASES;
```

After selecting the locally configured WordPress database:

```sql
SHOW TABLES;
SELECT user_login FROM wp_users;
```

The WordPress table prefix is normally `wp_` unless it has been changed.

## TLS verification

Inspect the certificate:

```sh
openssl s_client -connect <login>.42.fr:443 -servername <login>.42.fr </dev/null
```

Test TLS 1.2 and TLS 1.3:

```sh
openssl s_client -connect <login>.42.fr:443 -servername <login>.42.fr -tls1_2 </dev/null
openssl s_client -connect <login>.42.fr:443 -servername <login>.42.fr -tls1_3 </dev/null
```

HTTP port `80` should not be reachable because it is not published.

## Configuration changes

After changing a Dockerfile or a file copied during image build, rebuild the affected image:

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d --build nginx
```

For a complete rebuild:

```sh
make re
```

A port change may require updating both the service configuration and its corresponding Compose connection or port mapping. For example, changing PHP-FPM from port `9000` requires changing both the PHP-FPM `listen` value and NGINX `fastcgi_pass`.

## Validation checklist

Before submission, verify:

```sh
git status
git check-ignore -v srcs/.env
git check-ignore -v secrets/db_password.txt
sh -n srcs/requirements/mariadb/tools/init.sh
sh -n srcs/requirements/wordpress/tools/init.sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
docker network inspect inception
docker volume inspect mariadb_data
docker volume inspect wordpress_data
```

Also confirm:

- only port `443` is published;
- HTTP access fails;
- HTTPS shows the configured WordPress site instead of the installation page;
- both WordPress users exist;
- the administrator username does not contain `admin`;
- the normal user can log in and comment;
- the administrator can edit a page;
- data remains after stopping containers and rebooting the VM;
- no secret file or `.env` file is committed to Git;
- all source files and documentation are committed before submission.
