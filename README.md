# Inception — readable mandatory version

This version keeps the small architecture of the minimal project, but avoids compressed code.
Commands, YAML values, and configuration directives are written on separate lines so each part can be explained during evaluation.

## Architecture

- NGINX is the only service published to the host, on port 443.
- NGINX forwards PHP requests to WordPress through FastCGI on port 9000.
- WordPress connects to MariaDB on port 3306.
- WordPress and MariaDB data are stored under `/home/<login>/data`.
- Passwords are mounted as Docker secrets under `/run/secrets`.

## Create the secrets

```sh
mkdir -p secrets

openssl rand -hex 24 > secrets/db_root_password.txt
openssl rand -hex 24 > secrets/db_password.txt
openssl rand -hex 24 > secrets/wp_admin_password.txt
openssl rand -hex 24 > secrets/wp_user_password.txt

chmod 600 secrets/*.txt
```

## Start the project

```sh
make
```

Add the following entry to `/etc/hosts`:

```text
127.0.0.1 sel-jazo.42.fr
```

Then open:

```text
https://sel-jazo.42.fr
```

The browser warns about the certificate because it is self-signed.

## Useful commands

```sh
make status
make logs
make down
make re
```

## Why this version is still small

- It uses Compose health checking instead of a second database waiting loop in WordPress.
- It reuses Debian's standard NGINX and PHP-FPM configuration.
- NGINX does not require an entrypoint script.
- Only MariaDB and WordPress need initialization scripts.

The code is intentionally expanded for readability; it is not expanded with unnecessary logic.
