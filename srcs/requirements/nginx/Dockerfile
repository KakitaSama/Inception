FROM debian:12

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        nginx \
        openssl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY conf/nginx.conf.template \
    /etc/nginx/templates/nginx.conf.template

COPY tools/entrypoint.sh \
    /usr/local/bin/nginx-entrypoint

RUN rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p \
        /etc/nginx/templates \
        /etc/nginx/ssl \
        /run/nginx \
        /var/www/html \
    && chmod 755 /usr/local/bin/nginx-entrypoint

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/nginx-entrypoint"]

CMD ["nginx", "-g", "daemon off;"]
