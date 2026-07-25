COMPOSE := docker compose --env-file srcs/.env -f srcs/docker-compose.yml
LOGIN := $(shell sed -n 's/^LOGIN=//p' srcs/.env)
DATA_DIR := /home/$(LOGIN)/data

all: up

check-env:
	@test -n "$(LOGIN)" || (echo "LOGIN is missing from srcs/.env"; exit 1)

dirs: check-env
	mkdir -p $(DATA_DIR)/mariadb
	mkdir -p $(DATA_DIR)/wordpress

config:
	$(COMPOSE) config -q

build: dirs config
	$(COMPOSE) build

up: dirs config
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down --remove-orphans

re: down up

.PHONY: all check-env dirs config build up down stop start restart ps logs clean re
