COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE := srcs/.env
COMPOSE := docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)
LOGIN := $(shell sed -n 's/^LOGIN=//p' $(ENV_FILE))
DATA_DIR := /home/$(LOGIN)/data

all: up

up: prepare
	$(COMPOSE) up --detach --build

prepare:
	mkdir -p $(DATA_DIR)/mariadb
	mkdir -p $(DATA_DIR)/wordpress
	$(COMPOSE) config --quiet

reset:
	$(MAKE) fclean
	$(MAKE) up

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs --follow

status:
	$(COMPOSE) ps

fclean:
	$(COMPOSE) down --volumes --remove-orphans
	sudo rm -rf $(DATA_DIR)/mariadb
	sudo rm -rf $(DATA_DIR)/wordpress

re: down up

.PHONY: all up prepare down logs status re
