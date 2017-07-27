################################################################################

BASEIMAGE_NAME		= $(DOCKER_PROJECT)/[*Docker base image name*]
BASEIMAGE_TAG		?= [*Docker base image tag*]

################################################################################

DOCKER_PROJECT		?= [*Docker project name*]
DOCKER_NAME		= [*Docker image name*]
DOCKER_TAG		?= [*Docker image tag*]
DOCKER_DESCRIPTION	= [*One sentence of project description goes here*]
DOCKER_PROJECT_URL	= [*Project url*]

DOCKER_RUN_OPTS		+= -v /var/run/docker.sock:/var/run/docker.sock

DOCKER_SUBDIR		+= devel

################################################################################

.PHONY: all build rebuild deploy run up destroy down rm start stop restart
.PHONY: status logs shell test clean clean-all

all: destroy build deploy logs test
build: docker-build
rebuild: docker-rebuild
deploy run up: docker-deploy
destroy down rm: docker-destroy
start: docker-start
stop: docker-stop
restart: docker-stop docker-start
status: docker-status
logs: docker-logs
logs-tail: docker-logs-tail
shell: docker-shell
test: docker-test
clean: destroy docker-clean
clean-all: clean
	@for SUBDIR in $(DOCKER_SUBDIR); do \
		cd $(abspath $(DOCKER_HOME_DIR))/$${SUBDIR}; \
		$(MAKE) clean; \
	done

################################################################################

DOCKER_HOME_DIR		?= .
DOCKER_MK_DIR		?= $(DOCKER_HOME_DIR)/../Mk
include $(DOCKER_MK_DIR)/docker.container.mk

################################################################################
