*This project has been created as part of the 42 curriculum by duukh.*

# Inception

## Description

Inception is a system-administration project that builds a small web infrastructure inside a virtual machine using Docker Compose.

The mandatory stack contains three custom services:

- NGINX as the only public entry point, using HTTPS on port 443.
- WordPress with PHP-FPM, without NGINX.
- MariaDB, without NGINX.

The project uses one Docker bridge network and two named volumes for persistent MariaDB and WordPress data.

## Main design choices

- Debian 12 is used as the penultimate stable Debian base.
- Each service has its own Dockerfile and container.
- Only NGINX publishes a host port.
- WordPress connects to MariaDB using the service name `mariadb`.
- NGINX connects to PHP-FPM using the service name `wordpress`.
- Confidential values are supplied through Docker Compose secrets.

## Technology comparisons

### Virtual machines versus Docker

A virtual machine virtualizes a complete machine and runs its own kernel. Docker containers isolate processes while sharing the host kernel.

### Secrets versus environment variables

Environment variables are convenient for non-sensitive configuration. Secrets are mounted only into services that need them and are used here for passwords.

### Docker network versus host network

A Docker bridge network provides isolated container networking and service-name resolution. Host networking removes normal network isolation and is not used.

### Docker volumes versus bind mounts

Docker named volumes provide persistent storage independent of a container. The project uses named volumes configured to store data under `/home/duukh/data`.

## Instructions

The project is under implementation.

The final stack will be built and started with:

```bash
make
```

Compose configuration can currently be validated with:

```bash
make config
```

## Resources

Primary resources include the official Docker documentation, the Inception subject and the official peer-evaluation sheet.

AI was used to explain concepts, organize the implementation plan, review configuration choices and propose tests. Every generated command and configuration is reviewed and tested manually before inclusion.
