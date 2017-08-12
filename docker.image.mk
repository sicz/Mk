################################################################################

# GitHub repository
# git config --get remote.origin.url
# - https://github.com/sicz/docker-baseimage.git
# - git@github.com:sicz/docker-baseimage.git
GITHUB_URL		?= $(shell \
				git config --get remote.origin.url | \
				sed -E	-e "s|^git@github.com:|https://github.com/|" \
					-e "s|\.git$$||" \
			)
ifeq ($(GITHUB_URL),)
$(error "Not a git repository (or any of the parent directories)")
endif

GITHUB_USER		?= $(shell basename $$(dirname $(GITHUB_URL)))
GITHUB_REPOSITORY	?= $(shell basename $(GITHUB_URL))

# All modifications are commited
ifeq ($(shell git status --porcelain),)
# Last commit revision
VCS_REF			?= $(shell git rev-parse --short HEAD)
# Last commit timestamp
ifeq ($(shell uname),Darwin)
BUILD_DATE		?= $(shell date -u -r `git log -1 $(VCS_REF) --date=unix --format=%cd` "+%Y-%m-%dT%H:%M:%SZ")
else
BUILD_DATE		?= $(shell date -u -d @`git log -1 $(VCS_REF) --date=unix --format=%cd` "+%Y-%m-%dT%H:%M:%SZ")
endif

# Modifications are not commited
else
# Uncommited changes
VCS_REF			?= $(shell git rev-parse --short HEAD)-devel
# Build date contains only date so subsequent builds are cached
BUILD_DATE		?= $(shell date -u "+%Y-%m-%d")
endif

################################################################################

# Project directories
PROJECT_HOME_DIR	?= $(CURDIR)
DOCKER_BUILD_DIR	?= $(PROJECT_HOME_DIR)
TEST_DIR		?= $(DOCKER_BUILD_DIR)
DOCKER_VARIANT_DIR	?= $(PROJECT_HOME_DIR)

################################################################################

# Baseimage name
BASE_IMAGE		?= $(BASE_IMAGE_NAME):$(BASE_IMAGE_TAG)

################################################################################

# Docker name
DOCKER_PROJECT		?= $(GITHUB_USER)
DOCKER_NAME		?= $(shell echo $(GITHUB_REPOSITORY) | sed -E -e "s|^docker-||")
DOCKER_IMAGE_TAG	?= $(BASE_IMAGE_TAG)

# Docker image name
DOCKER_IMAGE_NAME	?= $(DOCKER_PROJECT)/$(DOCKER_NAME)
DOCKER_IMAGE		?= $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)

################################################################################

# Dockerfile name
DOCKER_FILE		?= Dockerfile
DOCKER_BUILD_FILE	?= $(abspath $(DOCKER_BUILD_DIR)/$(DOCKER_FILE))

# Build image with tags
DOCKER_BUILD_OPTS	+= --tag $(DOCKER_IMAGE) \
			   $(foreach TAG,$(DOCKER_IMAGE_TAGS),--tag $(DOCKER_IMAGE_NAME):$(TAG))

# Use http proxy when building image
ifdef http_proxy
DOCKER_BUILD_OPTS	+= --build-arg http_proxy=$(http_proxy)
else ifdef HTTP_PROXY
DOCKER_BUILD_OPTS	+= --build-arg http_proxy=$(HTTP_PROXY)
endif

# Dockerfile build arguments
DOCKER_BUILD_OPTS	+= $(foreach DOCKER_VAR,$(DOCKER_BUILD_VARS),--build-arg "$(DOCKER_VAR)=$($(DOCKER_VAR))")
DOCKER_BUILD_VARS	+= BASE_IMAGE \
			   BASE_IMAGE_NAME \
			   BASE_IMAGE_TAG \
			   BUILD_DATE \
			   DOCKER_IMAGE \
			   DOCKER_IMAGE_NAME \
			   DOCKER_IMAGE_TAG \
			   DOCKER_NAME \
			   DOCKER_PROJECT \
			   DOCKER_PROJECT_DESC \
			   DOCKER_PROJECT_URL \
			   DOCKER_REGISTRY \
			   GITHUB_REPOSITORY \
			   GITHUB_URL \
			   GITHUB_USER \
			   VCS_REF

################################################################################

# Docker executor type:
# container - classic Docker container
# compose - Docker Compose service
# stack - Docker Swarm stack
ifneq ($(wildcard $(STACK_FILE)),)
DOCKER_EXECUTOR		?= stack
else ifneq ($(wildcard $(COMPOSE_FILE)),)
DOCKER_EXECUTOR		?= compose
else
DOCKER_EXECUTOR		?= stack
endif


DOCKER_CONFIG_TARGET	?= docker-$(DOCKER_EXECUTOR)-config
DOCKER_START_TARGET	?= docker-$(DOCKER_EXECUTOR)-start
DOCKER_STOP_TARGET	?= docker-$(DOCKER_EXECUTOR)-stop
DOCKER_DESTROY_TARGET	?= docker-$(DOCKER_EXECUTOR)-destroy
DOCKER_PS_TARGET	?= docker-$(DOCKER_EXECUTOR)-ps
DOCKER_LOGS_TARGET	?= docker-$(DOCKER_EXECUTOR)-logs
DOCKER_LOGS_TAIL_TARGET	?= docker-$(DOCKER_EXECUTOR)-logs-tail

################################################################################

# Unique project id
DOCKER_PROJECT_ID_FILE	?= .docker-project-id
DOCKER_PROJECT_ID	?= $(shell \
				if [ -e $(DOCKER_PROJECT_ID_FILE) ]; then \
					cat $(DOCKER_PROJECT_ID_FILE); \
				else \
					openssl rand -hex 4 | \
					tee $(DOCKER_PROJECT_ID_FILE); \
				fi \
			   )

################################################################################

# Docker container name
CONTAINER_NAME_FILE	?= .docker-container-name
CONTAINER_NAME_HELPER	?= $(DOCKER_NAME)

ifeq ($(DOCKER_EXECUTOR),container)
CONTAINER_NAME		?= $(shell \
				if [ -e $(CONTAINER_NAME_FILE) ]; then \
					cat $(CONTAINER_NAME_FILE); \
				else \
					echo "$(DOCKER_PROJECT_ID)_$(CONTAINER_NAME_HELPER)" | \
					sed -E -e "s/[^[:alnum:]_]+/_/g"; \
				fi \
			)
else ifeq ($(DOCKER_EXECUTOR),compose)
CONTAINER_NAME		?= $(shell \
				if [ -e $(CONTAINER_NAME_FILE) ]; then \
					cat $(CONTAINER_NAME_FILE); \
				else \
					echo "$(DOCKER_PROJECT_ID)_$(CONTAINER_NAME_HELPER)_1" | \
					sed -E -e "s/[^[:alnum:]_]+/_/g"; \
				fi \
			)
else ifeq ($(DOCKER_EXECUTOR),stack)
# TODO: Docker Swarm Stack executor
$(error Docker executor "$(DOCKER_ERROR)" is not yet implemented)
# CONTAINER_NAME	?= $(shell \
# 				if [ -e $(CONTAINER_NAME_FILE) ]; then \
# 					cat $(CONTAINER_NAME_FILE); \
# 				else \
# 					echo "$(DOCKER_PROJECT_ID)_$(DOCKER_NAME)_1" | \
#					sed -E "s/[^[:alnum:]_]+/_/g"; \
# 				fi \
# 			)
else
$(error Unknown Docker executor "$(DOCKER_ERROR)")
endif

################################################################################

# Variables available in running container
CONTAINER_VARS		+= $(DOCKER_BUILD_VARS) \
			   DOCKER_ENTRYPOINT_INFO \
			   DOCKER_ENTRYPOINT_DEBUG

# Output docker-entrypoint.sh info messages on container start
DOCKER_ENTRYPOINT_INFO	?= yes

# Variables used in container environments
CONTAINER_OPTS		+= $(foreach DOCKER_VAR,$(CONTAINER_VARS),--env "$(DOCKER_VAR)=$($(DOCKER_VAR))")

# Run commands as user
ifdef CONTAINER_USER
CONTAINER_OPTS		+= --user $(CONTAINER_USER)
endif

################################################################################

# Docker Compose file
COMPOSE_FILE		?= $(abspath $(PROJECT_HOME_DIR)/docker-compose.yml)

# Variables used in Docker Compose file
COMPOSE_VARS		+= $(CONTAINER_VARS) \
			   COMPOSE_PROJECT_NAME \
			   COMPOSE_FILE

# Docker Compose project name
COMPOSE_PROJECT_NAME_FILE ?= .docker-compose-project-name
COMPOSE_PROJECT_NAME	?= $(shell \
				if [ -e $(COMPOSE_PROJECT_NAME_FILE) ]; then \
					cat $(COMPOSE_PROJECT_NAME_FILE); \
				else \
					echo "$(DOCKER_PROJECT_ID)"; \
				fi \
			   )

# Docker Compose command
COMPOSE_CMD		?= export $(foreach DOCKER_VAR,$(COMPOSE_VARS),$(DOCKER_VAR)="$($(DOCKER_VAR))"); \
			   docker-compose

# Docker Compose up options
COMPOSE_OPTS		+= -d --no-build

# Docker Compose down
COMPOSE_RM_OPTS		+= --remove-orphans

################################################################################

# Docker Stack file
STACK_FILE		?= $(abspath $(PROJECT_HOME_DIR)/docker-stack.yml)

# Docker Stack project name
STACK_PROJECT_NAME_FILE	?= .docker-stack-project-name
STACK_PROJECT_NAME		?= $(shell \
				if [ -e $(STACK_PROJECT_NAME_FILE) ]; then \
					cat $(STACK_PROJECT_NAME_FILE); \
				else \
					echo "$(DOCKER_PROJECT_ID)"; \
				fi \
			   )

# Variables used in Docker Stack file
STACK_VARS		+= $(COMPOSE_VARS)

# TODO: Docker Swarm Stack executor

################################################################################

# Docker shell options and command
DOCKER_SHELL_OPTS	+= --interactive --tty
DOCKER_SHELL_CMD	?= /bin/bash

# Run shell as user
ifdef CONTAINER_USER
DOCKER_SHELL_OPTS	+= --user $(CONTAINER_USER)
endif

################################################################################

# Docker test image
TEST_IMAGE_NAME		?= sicz/dockerspec
TEST_IMAGE_TAG		?= latest
TEST_IMAGE		?= $(TEST_IMAGE_NAME):$(TEST_IMAGE_TAG)

# Docker test options, command and args
TEST_VARS		+= $(COMPOSE_VARS) \
			   CONTAINER_NAME
TEST_OPTS		+= --interactive \
			   --tty \
			   --name $(TEST_CONTAINER_NAME) \
			   $(foreach DOCKER_VAR,$(TEST_VARS),--env "$(DOCKER_VAR)=$($(DOCKER_VAR))") \
			   --volume $(abspath $(TEST_DIR))/.rspec:/.rspec \
			   --volume $(abspath $(TEST_DIR))/spec:/spec \
			   --volume /var/run/docker.sock:/var/run/docker.sock \
			   --rm
TEST_CMD		?= rspec
TEST_ARGS		?= --format $(RSPEC_FORMAT)

# Rspec output format
RSPEC_FORMAT		?= documentation

TEST_CONTAINER_NAME_FILE ?= .docker-container-test
TEST_CONTAINER_NAME 	?= $(shell \
				if [ -e $(TEST_CONTAINER_NAME_FILE) ];  then \
					cat $(TEST_CONTAINER_NAME_FILE) 2> /dev/null; \
				else \
					echo "$(COMPOSE_PROJECT_NAME)_$(TEST_IMAGE_NAME)" | \
					sed -E "s/[^[:alnum:]_]+/_/g"; \
				fi \
			   )

# CircleCI configuration file
CIRCLE_CONFIG_FILE	?= $(PROJECT_HOME_DIR)/.circleci/config.yml

################################################################################

# Docker registry
DOCKER_REGISTRY		?= docker.io

# Tags that will be pushed/pulled to/from Docker repository
DOCKER_PUSH_TAGS	?= $(DOCKER_IMAGE_TAG) $(DOCKER_IMAGE_TAGS)
DOCKER_PULL_TAGS	?= $(DOCKER_PUSH_TAGS)

################################################################################

DOCKER_ALL_TARGETS	+= docker-pull \
			   docker-pull-baseimage \
			   docker-pull-testimage

################################################################################

ECHO			= /bin/echo

################################################################################

# Required variables
ifndef DOCKER_PROJECT
$(error Unable to determine Docker project name. Define DOCKER_PROJECT.)
endif
ifndef DOCKER_NAME
$(error Unable to determine Docker image name. Define DOCKER_NAME.)
endif
ifndef DOCKER_IMAGE_TAG
$(error Unable to determine Docker image tag. Define DOCKER_IMAGE_TAG.)
endif
ifndef BASE_IMAGE_NAME
$(error Unable to determine base image name. Define BASE_IMAGE_NAME.)
endif
ifndef BASE_IMAGE_TAG
$(error Unable to determine base image tag. Define BASE_IMAGE_TAG.)
endif

################################################################################

DOCKER_INFO_VARS	?= GITHUB_INFO \
			   BASE_IMAGE_INFO \
			   DOCKER_IMAGE_INFO \
			   DOCKER_BUILD_INFO \
			   DOCKER_DOCKER_INFO \
			   CONTAINER_INFO \
			   COMPOSE_INFO \
			   STACK_INFO \
			   DOCKER_SHELL_INFO \
			   TEST_INFO \
			   DOCKER_REGISTRY_INFO \
			   DOCKER_ALL_TARGETS_INFO

# Display GitHub variables
define GITHUB_INFO
GITHUB_URL:		$(GITHUB_URL)
GITHUB_USER:		$(GITHUB_USER)
GITHUB_REPOSITORY:	$(GITHUB_REPOSITORY)

BUILD_DATE:		$(BUILD_DATE)
VCS_REF:		$(VCS_REF)
endef
export GITHUB_INFO

# Display Docker variables
define BASE_IMAGE_INFO
BASE_IMAGE_NAME:	$(BASE_IMAGE_NAME)
BASE_IMAGE_TAG:		$(BASE_IMAGE_TAG)
BASE_IMAGE:		$(BASE_IMAGE)
endef
export BASE_IMAGE_INFO

define DOCKER_IMAGE_INFO
DOCKER_PROJECT:		$(DOCKER_PROJECT)
DOCKER_NAME:		$(DOCKER_NAME)
DOCKER_IMAGE_TAG:	$(DOCKER_IMAGE_TAG)
DOCKER_IMAGE_TAGS:	$(DOCKER_IMAGE_TAGS)
DOCKER_IMAGE_NAME:	$(DOCKER_IMAGE_NAME)
DOCKER_IMAGE:		$(DOCKER_IMAGE)
DOCKER_FILE		$(DOCKER_FILE)
endef
export DOCKER_IMAGE_INFO

define DOCKER_BUILD_INFO
CURDIR:			$(CURDIR)
PROJECT_HOME_DIR:	$(PROJECT_HOME_DIR)
DOCKER_VARIANT_DIR:	$(DOCKER_VARIANT_DIR)

DOCKER_BUILD_DIR:	$(DOCKER_BUILD_DIR)
DOCKER_BUILD_FILE:	$(DOCKER_BUILD_FILE)
DOCKER_BUILD_VARS:	$(DOCKER_BUILD_VARS)
DOCKER_BUILD_OPTS:	$(DOCKER_BUILD_OPTS)
endef
export DOCKER_BUILD_INFO

define DOCKER_DOCKER_INFO
DOCKER_EXECUTOR:	$(DOCKER_EXECUTOR)
DOCKER_CONFIG_TARGET:	$(DOCKER_CONFIG_TARGET)
DOCKER_START_TARGET:	$(DOCKER_START_TARGET)
DOCKER_STOP_TARGET:	$(DOCKER_STOP_TARGET)
DOCKER_DESTROY_TARGET:	$(DOCKER_DESTROY_TARGET)
DOCKER_PS_TARGET:	$(DOCKER_PS_TARGET)
DOCKER_LOGS_TARGET:	$(DOCKER_LOGS_TARGET)
DOCKER_LOGS_TAIL_TARGET: $(DOCKER_LOGS_TAIL_TARGET)

DOCKER_PROJECT_ID_FILE:	$(DOCKER_PROJECT_ID_FILE)
DOCKER_PROJECT_ID:	$(DOCKER_PROJECT_ID)
endef
export DOCKER_DOCKER_INFO

define CONTAINER_INFO
CONTAINER_NAME:		$(CONTAINER_NAME)
CONTAINER_NAME_FILE:	$(CONTAINER_NAME_FILE)
CONTAINER_USER:		$(CONTAINER_USER)
CONTAINER_VARS:		$(CONTAINER_VARS)
CONTAINER_OPTS:		$(CONTAINER_OPTS)
CONTAINER_CMD:		$(CONTAINER_CMD)
CONTAINER_START_OPTS:	$(CONTAINER_START_OPTS)
CONTAINER_STOP_OPTS:	$(CONTAINER_STOP_OPTS)
CONTAINER_RM_OPTS:	$(CONTAINER_RM_OPTS)
CONTAINER_LOGS_OPTS:	$(CONTAINER_LOGS_OPTS)
endef
export CONTAINER_INFO

define COMPOSE_INFO
COMPOSE_FILE:		$(COMPOSE_FILE)
COMPOSE_PROJECT_NAME:	$(COMPOSE_PROJECT_NAME)
COMPOSE_PROJECT_NAME_FILE: $(COMPOSE_PROJECT_NAME_FILE)
COMPOSE_VARS:		$(COMPOSE_VARS)
COMPOSE_CMD:		$(COMPOSE_CMD)
COMPOSE_OPTS:		$(COMPOSE_OPTS)
COMPOSE_STOP_OPTS: 	$(COMPOSE_STOP_OPTS)
COMPOSE_RM_OPTS:	$(COMPOSE_RM_OPTS)
COMPOSE_LOGS_OPTS: 	$(COMPOSE_LOGS_OPTS)
COMPOSE_PS_OPTS:	$(COMPOSE_PS_OPTS)
COMPOSE_CONFIG_OPTS: 	$(COMPOSE_CONFIG_OPTS)
endef
export COMPOSE_INFO

define STACK_INFO
STACK_FILE:		$(STACK_FILE)
STACK_PROJECT_NAME:	$(STACK_PROJECT_NAME)
STACK_PROJECT_NAME_FILE: $(STACK_PROJECT_NAME_FILE)
endef
export STACK_INFO

define DOCKER_SHELL_INFO
DOCKER_SHELL_OPTS:	$(DOCKER_SHELL_OPTS)
DOCKER_SHELL_CMD:	$(DOCKER_SHELL_CMD)
endef
export DOCKER_SHELL_INFO

define TEST_INFO
TEST_DIR:		$(TEST_DIR)
TEST_IMAGE_NAME:	$(TEST_IMAGE_NAME)
TEST_IMAGE_TAG:		$(TEST_IMAGE_TAG)
TEST_IMAGE:		$(TEST_IMAGE)
TEST_VARS:		$(TEST_VARS)
TEST_OPTS:		$(TEST_OPTS)
TEST_CMD:		$(TEST_CMD)
TEST_ARGS:		$(TEST_ARGS)
TEST_CONTAINER_NAME: 	$(TEST_CONTAINER_NAME)
TEST_CONTAINER_NAME_FILE: $(TEST_CONTAINER_NAME_FILE)
endef
export TEST_INFO

define DOCKER_REGISTRY_INFO
DOCKER_REGISTRY:	$(DOCKER_REGISTRY)
DOCKER_PUSH_TAGS:	$(DOCKER_PUSH_TAGS)
DOCKER_PULL_TAGS:	$(DOCKER_PULL_TAGS)
endef
export DOCKER_REGISTRY_INFO

define DOCKER_ALL_TARGETS_INFO
DOCKER_ALL_TARGETS:	$(DOCKER_ALL_TARGETS)
endef
export DOCKER_ALL_TARGETS_INFO

################################################################################

.PHONY: docker-info
docker-info:
	@set -eo pipefail; \
	( \
		$(foreach DOCKER_VAR,$(DOCKER_INFO_VARS), \
			$(ECHO) "$${$(DOCKER_VAR)}"; \
			$(ECHO); \
		) \
	) | sed -E \
		-e $$'s/ +-/\\\n\\\t\\\t\\\t-/g' \
		-e $$'s/ +([A-Z][A-Z]+)/\\\n\\\t\\\t\\\t\\1/g' \
		-e $$'s/(;) */\\1\\\n\\\t\\\t\\\t/g'

################################################################################

# Build Docker image with cached layers
.PHONY: docker-build
docker-build:
	@set -eo pipefail; \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_BUILD_FILE) $(DOCKER_BUILD_DIR)

# Build Docker image without cached layers
.PHONY: docker-rebuild
docker-rebuild:
	@set -eo pipefail; \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_BUILD_FILE) --no-cache $(DOCKER_BUILD_DIR)

# Tag Docker image
.PHONY: docker-tag
docker-tag:
	@set -eo pipefail; \
	if [ -n "$(DOCKER_IMAGE_TAGS)" ]; then \
		$(ECHO) -n "Tagging image with tags: "; \
		for DOCKER_IMAGE_TAG in $(DOCKER_IMAGE_TAGS); do \
			$(ECHO) -n "$${DOCKER_IMAGE_TAG}"; \
			docker tag $(DOCKER_IMAGE) $(DOCKER_IMAGE_NAME):$${DOCKER_IMAGE_TAG}; \
		done; \
		$(ECHO); \
	fi

################################################################################

# Display containers config
.PHONY: docker-config
docker-config: $(DOCKER_CONFIG_TARGET)
	@true

# Start fresh containers
.PHONY: docker-deploy
docker-deploy:
	@set -oe pipefail; \
	$(MAKE) docker-destroy; \
	$(MAKE) docker-start

# Start containers
.PHONY: docker-start
docker-start: $(DOCKER_START_TARGET)
	@true

# Stop containers
.PHONY: docker-stop
docker-stop: $(DOCKER_STOP_TARGET)
	@true

# Destroy containers
.PHONY: docker-destroy
docker-destroy: $(DOCKER_DESTROY_TARGET)
	@true

# Show info about running containers
.PHONY: docker-ps
docker-ps: $(DOCKER_PS_TARGET)
	@true

# Show containers logs
.PHONY: docker-logs
docker-logs: $(DOCKER_LOGS_TARGET)
	@true

# Follow containers logs
.PHONY: docker-logs-tail
docker-logs-tail: $(DOCKER_LOGS_TAIL_TARGET)
	@true

################################################################################

.PHONY: docker-container-config
docker-container-config:
	@true

.PHONY: docker-container-create
docker-container-create:
	@set -eo pipefail; \
	if [ -z "$$(docker container ls --all --quiet --filter 'name=^/$(CONTAINER_NAME)$$')" ]; then \
		$(ECHO) -n "Creating container: "; \
		$(ECHO) "$(CONTAINER_NAME)" > $(CONTAINER_NAME_FILE); \
		docker create $(CONTAINER_OPTS) --name $(CONTAINER_NAME) $(DOCKER_IMAGE) $(CONTAINER_CMD) > /dev/null; \
		$(ECHO) "$(CONTAINER_NAME)"; \
	fi; \

.PHONY: docker-container-start
docker-container-start: docker-container-create
	@set -eo pipefail; \
	if [ -z "$$(docker container ls --quiet --filter 'name=^/$(CONTAINER_NAME)$$')" ]; then \
		$(ECHO) -n "Starting container: "; \
		docker start $(CONTAINER_START_OPTS) $(CONTAINER_NAME) > /dev/null; \
		$(ECHO) "$(CONTAINER_NAME)"; \
	fi; \

.PHONY: docker-container-stop
docker-container-stop:
	@set -eo pipefail; \
	if [ -n "$$(docker container ls --quiet --filter 'name=^/$(CONTAINER_NAME)$$')" ]; then \
		$(ECHO) -n "Stopping container: "; \
		docker stop $(CONTAINER_STOP_OPTS) $(CONTAINER_NAME) > /dev/null; \
		$(ECHO) "$(CONTAINER_NAME)"; \
	fi; \

.PHONY: docker-container-destroy
docker-container-destroy: docker-container-stop
	@set -eo pipefail; \
	if [ -n "$$(docker container ls --all --quiet --filter 'name=^/$(CONTAINER_NAME)$$')" ]; then \
		$(ECHO) -n "Destroying container: "; \
		docker container rm --force $(CONTAINER_RM_OPTS) $(CONTAINER_NAME) > /dev/null; \
		$(ECHO) "$(CONTAINER_NAME)"; \
	fi; \
	rm -f $(CONTAINER_NAME_FILE)

.PHONY: docker-container-ps
docker-container-ps:
	@set -eo pipefail; \
	docker container ls --all --filter 'name=^/$(CONTAINER_NAME)$$'

.PHONY: docker-container-logs
docker-container-logs:
	@set -eo pipefail; \
	if [ -n "$$(docker container ls --quiet --filter 'name=^/$(CONTAINER_NAME)$$')" ]; then \
		docker container logs $(CONTAINER_LOGS_OPTS) $(CONTAINER_NAME); \
	fi

.PHONY: docker-container-logs-tail
docker-container-logs-tail:
	-@set -eo pipefail; \
	if [ -n "$$(docker container ls --quiet --filter 'name=^/$(CONTAINER_NAME)$$')" ]; then \
		docker container logs --follow $(CONTAINER_LOGS_OPTS) $(CONTAINER_NAME); \
	fi

################################################################################

# Display containers configuraion
.PHONY: docker-compose-config
docker-compose-config:
	@set -eo pipefail; \
	$(COMPOSE_CMD) config $(COMPOSE_CONFIG_OPTS)

# Start fresh containers
.PHONY: docker-compose-start
docker-compose-start:
	@set -eo pipefail; \
	$(ECHO) "$(COMPOSE_PROJECT_NAME)" > $(COMPOSE_PROJECT_NAME_FILE); \
	$(ECHO) "$(CONTAINER_NAME)" > $(CONTAINER_NAME_FILE); \
	cd $(PROJECT_HOME_DIR); \
	$(COMPOSE_CMD) up $(COMPOSE_OPTS) $(COMPOSE_STOP_OPTS) $(COMPOSE_RM_OPTS)

# Stop containers
.PHONY: docker-compose-stop
docker-compose-stop:
	@set -eo pipefail; \
	if [ -e "$(COMPOSE_PROJECT_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) stop $(COMPOSE_STOP_OPTS); \
	fi

# Destroy containers
.PHONY: docker-destroy
docker-compose-destroy:
	@set -eo pipefail; \
	if [ -e "$(COMPOSE_PROJECT_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) down $(COMPOSE_RM_OPTS); \
		rm -f "$(COMPOSE_PROJECT_NAME_FILE)"; \
	fi

# List running containers
.PHONY: docker-compose-ps
docker-compose-ps:
	@set -eo pipefail; \
	$(COMPOSE_CMD) ps $(COMPOSE_PS_OPTS); \

# Display containers logs
.PHONY: docker-compose-logs
docker-compose-logs:
	@set -eo pipefail; \
	if [ -e "$(COMPOSE_PROJECT_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) logs $(COMPOSE_LOGS_OPTS); \
	fi

# Follow container logs
.PHONY: docker-compose-logs-tail
docker-compose-logs-tail:
	-@set -eo pipefail; \
	if [ -e "$(COMPOSE_PROJECT_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) logs --follow $(COMPOSE_LOGS_OPTS); \
	fi

################################################################################

# Run shell in the container
.PHONY: docker-shell
docker-shell: docker-start
	@set -eo pipefail; \
	docker exec $(DOCKER_SHELL_OPTS) $(CONTAINER_NAME) $(DOCKER_SHELL_CMD)

################################################################################

# Run tests
.PHONY: docker-test
docker-test: docker-start
	@set -eo pipefail; \
	echo $(TEST_CONTAINER_NAME) > $(TEST_CONTAINER_NAME_FILE); \
	docker run $(TEST_OPTS) $(TEST_IMAGE) $(TEST_CMD) $(TEST_ARGS); \
	rm -f $(TEST_CONTAINER_NAME_FILE)

################################################################################

# Clean project
.PHONY: docker-clean
docker-clean:
	@set -eo pipefail; \
	for STACK_PROJECT_NAME_FILE in `ls .docker-stack-* 2> /dev/null`; do \
		$(MAKE) docker-destroy \
			DOCKER_EXECUTOR=stack \
			STACK_PROJECT_NAME_FILE=$${STACK_PROJECT_NAME_FILE}; \
	done; \
	for COMPOSE_PROJECT_NAME_FILE in `ls .docker-compose-* 2> /dev/null`; do \
		$(MAKE) docker-destroy \
			DOCKER_EXECUTOR=compose \
			COMPOSE_PROJECT_NAME_FILE=$${COMPOSE_PROJECT_NAME_FILE}; \
	done; \
	for CONTAINER_NAME_FILE in `ls .docker-container-* 2> /dev/null`; do \
		$(MAKE) docker-destroy \
			DOCKER_EXECUTOR=container \
			CONTAINER_NAME_FILE=$${CONTAINER_NAME_FILE}; \
	done; \
	for DOCKER_ID_FILE in `ls .docker-* 2> /dev/null`; do \
		rm -f $${DOCKER_ID_FILE}; \
	done; \
	find $(PROJECT_HOME_DIR) -type f -name '*~' | xargs rm -f

################################################################################

# Pull project images from Docker registry
.PHONY: docker-pull
docker-pull:
	@set -eo pipefail; \
	$(foreach TAG,$(DOCKER_PULL_TAGS),docker pull $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);echo;)

# Pull base image from Docker registry
.PHONY: docker-pull-baseimage
docker-pull-baseimage:
	@set -eo pipefail; \
	docker pull $(BASE_IMAGE)

# Pull test image from Docker registry
.PHONY: docker-pull-testimage
docker-pull-testimage:
	@set -eo pipefail; \
	docker pull $(TEST_IMAGE)

# Posh project images to Docker registry
.PHONY: docker-push
docker-push:
	@set -eo pipefail; \
	$(foreach TAG,$(DOCKER_PUSH_TAGS),docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);echo;)


################################################################################

# Run $(DOCKER_TARGET) on all image versions
docker-all:
	@set -eo pipefail; \
	for DOCKER_SUBDIR in $(DOCKER_SUBDIRS); do \
		cd $(abspath $(DOCKER_VARIANT_DIR))/$${DOCKER_SUBDIR}; \
		if [ "$${DOCKER_SUBDIR}" = "." ]; then \
			DOCKER_SUBDIR="latest"; \
		fi; \
		$(ECHO); \
		$(ECHO); \
		$(ECHO) "===> $${DOCKER_SUBDIR}"; \
		$(ECHO); \
		$(ECHO); \
		$(MAKE) $(DOCKER_TARGET); \
	done

# Run target on all images in project
# DOCKER_ALL_TARGET:
# $1 - <TARGET>
define DOCKER_ALL_TARGET
.PHONY: $(1)-all
$(1)-all: ; @set -eo pipefail; $(MAKE) docker-all DOCKER_TARGET=$(1)
endef
$(foreach DOCKER_TARGET,$(DOCKER_ALL_TARGETS),$(eval $(call DOCKER_ALL_TARGET,$(DOCKER_TARGET))))

################################################################################

# Update Dockerspec tag in CircleCI configuration
.PHONY: circle-update-config
circle-update-config: docker-pull-testimage
	@set -eo pipefail; \
	TEST_IMAGE_DIGEST="$(shell docker image inspect $(TEST_IMAGE) --format '{{index .RepoDigests 0}}')"; \
	sed -i~ -E -e "s|-[[:space:]]*image:[[:space:]]*$(TEST_IMAGE_NAME)(@sha256)?:.*|- image: $${TEST_IMAGE_DIGEST}|" $(CIRCLE_CONFIG_FILE); \
	if diff $(CIRCLE_CONFIG_FILE)~ $(CIRCLE_CONFIG_FILE) > /dev/null; then \
		$(ECHO) "CircleCI configuration is up-to-date"; \
	else \
		$(ECHO) "Updating CircleCI Docker executor image to: $${TEST_IMAGE_DIGEST}"; \
	fi; \
	rm -f $(CIRCLE_CONFIG_FILE)~

################################################################################
