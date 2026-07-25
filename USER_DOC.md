# Inception User Documentation

## Services

The stack provides:

- An HTTPS WordPress website through NGINX.
- A WordPress administration panel.
- A MariaDB database used internally by WordPress.

## Starting the project

```bash
make
```

## Stopping the project

```bash
make down
```

## Checking service status

```bash
make ps
```

## Viewing logs

```bash
make logs
```

## Website access

The final website will be available at:

```text
https://
```

The WordPress administration panel will be available at:

```text
https:///wp-admin
```

## Credentials

Local password files are stored under the repository's `secrets/` directory and are ignored by Git.

Do not commit or publicly share their contents.

## Current status

The repository structure and Compose configuration are implemented. The individual services are still under development.
