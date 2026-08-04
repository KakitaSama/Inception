FROM debian:bookworm

ARG DOMAIN_NAME

RUN apt-get update \
    && apt-get install --yes --no-install-recommends nginx openssl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/nginx/ssl

COPY conf/default /etc/nginx/sites-available/default

RUN sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" /etc/nginx/sites-available/default \
    && openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 365 -keyout /etc/nginx/ssl/inception.key -out /etc/nginx/ssl/inception.crt -subj "/C=MA/O=42/CN=${DOMAIN_NAME}" -addext "subjectAltName=DNS:${DOMAIN_NAME}"

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
