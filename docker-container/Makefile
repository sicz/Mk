DOCKER_PROJECT		= PROJECT
DOCKER_NAME		= NAME
DOCKER_TAG		= latest

BASE_IMAGE_TAG		= latest

.PHONY: all build rebuild deploy run up destroy down clean rm start stop restart
.PHONY: status logs shell refresh test

all: destroy build deploy logs-tail
build: docker-build
rebuild: docker-rebuild
deploy run up: docker-deploy
destroy down clean rm: docker-destroy
start: docker-start
stop: docker-stop
restart: docker-stop docker-start
status: docker-status
logs: docker-logs
logs-tail: docker-logs-tail
shell: docker-shell
refresh: docker-refresh
test: docker-test

include ../Mk/docker.container.mk
