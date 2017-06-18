DOCKER_PROJECT		?= [*Docker project name*]
DOCKER_NAME		= [*Docker image name*]
DOCKER_TAG		= [*Docker image tag*]
DOCKER_DESCRIPTION	= [*One sentence of project description goes here*]
DOCKER_PROJECT_URL	= [*Project url*]

BASEIMAGE_NAME		= $(DOCKER_PROJECT)/[*Docker base image name*]
BASEIMAGE_TAG		= [*Docker base image tag*]

.PHONY: all build rebuild deploy run up destroy down clean rm start stop restart
.PHONY: status logs logs-tail shell test

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
test: docker-test

DOCKER_MK_DIR		?= ../Mk
include $(DOCKER_MK_DIR)/docker.container.mk
