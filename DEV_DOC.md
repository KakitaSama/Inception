# Inception Developer Documentation

## Prerequisites

- A Linux virtual machine
- Docker Engine
- Docker Compose
- GNU Make
- Git

## Project configuration

Non-secret variables are stored in:

```text
srcs/.env
```

Local confidential values are stored in ignored files under:

```text
secrets/
```

## Validate Compose

```bash
make config
```

## Build images

```bash
make build
```

## Start the stack

```bash
make
```

## Stop and remove containers

```bash
make down
```

## Persistent storage

MariaDB data is stored under:

```text
/home/sel-jazo/data/mariadb
```

WordPress files are stored under:

```text
/home/sel-jazo/data/wordpress
```

The Compose services access those directories through Docker named volumes.

## Main Compose file

```text
srcs/docker-compose.yml
```

## Current development status

The Compose model, network, named volumes, secrets layout and service build directories are present. Service-specific packages, configurations and entrypoints will be added next.
