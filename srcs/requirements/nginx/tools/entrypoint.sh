#!/bin/sh
set -eu

TEMPLATE=/etc/nginx/templates/nginx.conf.template
CONFIG=/etc/nginx/nginx.conf

SSL_DIR=/etc/nginx/ssl
CERTIFICATE="$SSL_DIR/inception.crt"
PRIVATE_KEY="$SSL_DIR/inception.key"

log()
{
    printf '%s\n' "[nginx-entrypoint] $*"
}

die()
{
    printf '%s\n' "[nginx-entrypoint] ERROR: $*" >&2
    exit 1
}

if [ "$#" -eq 0 ]; then
    set -- nginx -g 'daemon off;'
fi

if [ "$1" != "nginx" ]; then
    exec "$@"
fi

: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

case "$DOMAIN_NAME" in
    *[!A-Za-z0-9.-]*|'')
        die "DOMAIN_NAME contains unsupported characters"
        ;;
esac

case "$DOMAIN_NAME" in
    .*|*.|*..*)
        die "DOMAIN_NAME has an invalid format"
        ;;
esac

[ -r "$TEMPLATE" ] ||
    die "Missing NGINX configuration template: $TEMPLATE"

mkdir -p "$SSL_DIR" /run/nginx

log "Rendering configuration for $DOMAIN_NAME"

sed "s/__DOMAIN_NAME__/$DOMAIN_NAME/g" \
    "$TEMPLATE" \
    > "$CONFIG"

if [ ! -s "$CERTIFICATE" ] || [ ! -s "$PRIVATE_KEY" ]; then
    log "Generating a self-signed TLS certificate"

    rm -f "$CERTIFICATE" "$PRIVATE_KEY"

    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -sha256 \
        -days 365 \
        -keyout "$PRIVATE_KEY" \
        -out "$CERTIFICATE" \
        -subj "/C=MA/O=42/CN=$DOMAIN_NAME" \
        -addext "subjectAltName=DNS:$DOMAIN_NAME" \
        -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
        -addext "extendedKeyUsage=serverAuth"

    chmod 600 "$PRIVATE_KEY"
    chmod 644 "$CERTIFICATE"
fi

log "Validating NGINX configuration"

nginx -t

log "Starting NGINX as the container main process"

exec "$@"
