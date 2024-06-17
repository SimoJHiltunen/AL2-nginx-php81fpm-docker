.PHONY: build

###############################################
##     VARIABLES                             ##
###############################################
# Read project specific environment variables from .env file
include .env
export
# Makefile specific enviroment variables
compose=docker-compose
service=nginx-php
###############################################
##      TARGETS                              ##
###############################################
up:
	@echo "== START =="
	$(compose) up -d ${service}
stop:
	@echo "== STOP =="
	@$(compose) stop
build:
	@$(compose) build --no-cache --push --progress tty
logs:
	@$(compose) logs -ft --tail=1000
bash:
	@echo "== BASH =="
	@$(compose) exec ${service} bash
down:
	@$(compose) down --volumes --remove-orphans
  