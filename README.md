*This project has been created as part of the 42 curriculum by sel-jazo.*

# Inception

## Description

Inception is a system-administration project that builds a small web infrastructure with Docker Compose inside a virtual machine.

The project contains three services, each running in its own container and built from a custom Dockerfile based on Debian Bookworm:

- **NGINX** is the only public entry point. It accepts HTTPS connections on host port `443` and forwards PHP requests to WordPress through FastCGI.
- **WordPress with PHP-FPM** contains the website files and runs PHP-FPM on container port `9000`. It does not contain NGINX.
- **MariaDB** stores the WordPress database and listens inside the Docker network on container port `3306`. It does not contain NGINX.

Two Docker named volumes provide persistent storage:

- `mariadb_data` stores the database in `/home/sel-jazo/data/mariadb` on the host.
- `wordpress_data` stores the website files in `/home/sel-jazo/data/wordpress` on the host.

The containers communicate through the custom `inception` bridge network. Only NGINX publishes a host port.

### Project sources

The main files are organized as follows:

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        ├── nginx/
        └── wordpress/
```

Each service directory contains its own Dockerfile and the configuration or initialization files required by that service.

## Design choices

### Virtual machines and Docker

A virtual machine emulates a complete machine and runs its own operating-system kernel. Docker containers share the host kernel while isolating processes, filesystems, networks, and resources.

The project still runs inside a virtual machine because the subject requires it, while Docker divides the application into reproducible and isolated services inside that VM.

### Secrets and environment variables

Environment variables are used for non-confidential configuration such as the domain name, database name, usernames, and WordPress title.

Passwords are stored in files under `secrets/` and mounted inside containers under `/run/secrets`. This prevents passwords from being written in Dockerfiles or directly inside `docker-compose.yml`.

### Docker network and host network

The custom bridge network gives each service an internal DNS name. For example, NGINX reaches PHP-FPM through `wordpress:9000`, and WordPress reaches the database through `mariadb`.

Host networking is not used. The containers remain isolated from the host network, and only NGINX publishes port `443`.

### Docker volumes and bind mounts

The services use Docker named volumes instead of direct service-level bind-mount syntax. The local volume driver stores their data in the paths required by the subject under `/home/sel-jazo/data`.

The data survives container deletion and virtual-machine reboot because it is stored outside the containers' writable layers.

## Instructions

### Prerequisites

The virtual machine must have:

- Docker Engine
- Docker Compose v2
- GNU Make
- OpenSSL
- permission to create directories under `/home/sel-jazo/data`

### Configure the local domain

Add this line to `/etc/hosts` inside the virtual machine:

```text
127.0.0.1 sel-jazo.42.fr
```

When accessing the project from another machine, replace `127.0.0.1` with the virtual machine's reachable IP address.

### Create the secrets

The secret files are intentionally ignored by Git. Create them before starting the project:

```sh
mkdir -p secrets
openssl rand -hex 24 > secrets/db_root_password.txt
openssl rand -hex 24 > secrets/db_password.txt
openssl rand -hex 24 > secrets/wp_admin_password.txt
openssl rand -hex 24 > secrets/wp_user_password.txt
chmod 600 secrets/*.txt
```

### Build and start

From the repository root, run:

```sh
make
```

The website is then available at:

```text
https://sel-jazo.42.fr
```

The administration panel is available at:

```text
https://sel-jazo.42.fr/wp-admin
```

The certificate is self-signed, so the browser may display a warning.

### Stop and rebuild

```sh
make down
make re
```

To remove the containers, volumes, and host data directories, run:

```sh
make fclean
```

To perform a full cleanup followed by a new build, run:

```sh
make reset
```

### Check the running stack

```sh
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs
docker network ls
docker volume ls
```

More user-oriented instructions are available in `USER_DOC.md`. Development and maintenance details are available in `DEV_DOC.md`.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker networking](https://docs.docker.com/engine/network/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB documentation](https://mariadb.com/docs/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)
- [WordPress documentation](https://wordpress.org/documentation/)
- [WP-CLI documentation](https://developer.wordpress.org/cli/commands/)

### Use of AI

AI was also used to understand concepts, review syntax, identify possible configuration mistakes, and help draft the project documentation.
