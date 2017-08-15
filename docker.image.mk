### GITHUB #####################################################################

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

### PROJECT_DIRS ###############################################################

# Project directories
PROJECT_DIR		?= $(CURDIR)
BUILD_DIR		?= $(PROJECT_DIR)
TEST_DIR		?= $(BUILD_DIR)
DOCKER_VARIANT_DIR		?= $(BUILD_DIR)

### BASE_IMAGE #################################################################

# Baseimage name
BASE_IMAGE		?= $(BASE_IMAGE_NAME):$(BASE_IMAGE_TAG)

### DOCKER_IMAGE ###############################################################

# Docker name
DOCKER_PROJECT		?= $(GITHUB_USER)
DOCKER_NAME		?= $(shell echo $(GITHUB_REPOSITORY) | sed -E -e "s|^docker-||")
DOCKER_PROJECT_DESC	?= $(GITHUB_USER)/$(GITHUB_REPOSITORY)
DOCKER_PROJECT_URL	?= GITHUB_URL

# Docker image name
DOCKER_IMAGE_NAME	?= $(DOCKER_PROJECT)/$(DOCKER_NAME)
DOCKER_IMAGE		?= $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)

### BUILD ######################################################################

# Dockerfile name
DOCKER_FILE		?= Dockerfile
BUILD_DOCKER_FILE	?= $(abspath $(DOCKER_VARIANT_DIR)/$(DOCKER_FILE))

# Build image with tags
BUILD_OPTS		+= --tag $(DOCKER_IMAGE) \
			   $(foreach TAG,$(DOCKER_IMAGE_TAGS),--tag $(DOCKER_IMAGE_NAME):$(TAG))

# Use http proxy when building image
ifdef HTTP_PROXY
BUILD_OPTS		+= --build-arg HTTP_PROXY=$(http_proxy)
else ifdef http_proxy
BUILD_OPTS		+= --build-arg HTTP_PROXY=$(HTTP_PROXY)
endif

# Dockerfile build arguments
BUILD_OPTS		+= $(foreach VAR,$(BUILD_VARS),--build-arg "$(VAR)=$($(VAR))")
BUILD_VARS		+= BASE_IMAGE \
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

#### DOCKER_EXECUTOR ###########################################################

# Auto detect Docker executor type:
# container - classic Docker container
# compose - Docker Compose service
# stack - Docker Swarm stack
DOCKER_EXECUTOR		?= container

DOCKER_CONFIG_TARGET	?= docker-$(DOCKER_EXECUTOR)-config
DOCKER_START_TARGET	?= docker-$(DOCKER_EXECUTOR)-start
DOCKER_PS_TARGET	?= docker-$(DOCKER_EXECUTOR)-ps
DOCKER_LOGS_TARGET	?= docker-$(DOCKER_EXECUTOR)-logs
DOCKER_LOGS_TAIL_TARGET	?= docker-$(DOCKER_EXECUTOR)-logs-tail
DOCKER_TEST_TARGET	?= docker-$(DOCKER_EXECUTOR)-test
DOCKER_STOP_TARGET	?= docker-$(DOCKER_EXECUTOR)-stop
DOCKER_DESTROY_TARGET	?= docker-$(DOCKER_EXECUTOR)-destroy

# Unique project id
DOCKER_EXECUTOR_ID_FILE	?= .docker-executor-id
DOCKER_EXECUTOR_ID	:= $(shell \
				if [ -e $(DOCKER_EXECUTOR_ID_FILE) ]; then \
					cat $(DOCKER_EXECUTOR_ID_FILE); \
				else \
					openssl rand -hex 4 | \
					tee $(DOCKER_EXECUTOR_ID_FILE); \
				fi \
			   )

# Support multiple executor configurations
ifneq ($(DOCKER_CONFIGS),)
DOCKER_CONFIG_FILE	?= .docker-config
DOCKER_CONFIG		?= $(shell \
				if [ -e $(DOCKER_CONFIG_FILE) ]; then \
					cat $(DOCKER_CONFIG_FILE); \
				else \
					echo "default"; \
				fi \
			   )
endif

### CONTAINER_EXECUTOR #########################################################

# Docker container name
ifeq ($(DOCKER_EXECUTOR),container)
CONTAINER_NAME		?= $(shell \
				echo "$(DOCKER_EXECUTOR_ID)_$(DOCKER_NAME)" | \
				sed -E -e "s/[^[:alnum:]_]+/_/g" \
			   )
else ifeq ($(DOCKER_EXECUTOR),compose)
CONTAINER_NAME		?= $(DOCKER_EXECUTOR_ID)_$(COMPOSE_SERVICE_NAME)_1
else ifeq ($(DOCKER_EXECUTOR),stack)
# TODO: Docker Swarm Stack executor
CONTAINER_NAME		?= $(DOCKER_EXECUTOR_ID)_$(STACK_SERVICE_NAME)_1
else
$(error Unknown Docker executor "$(DOCKER_ERROR)")
endif

# Variables available in running container
CONTAINER_VARS		+= $(BUILD_VARS) \
			   DOCKER_ENTRYPOINT_INFO \
			   DOCKER_ENTRYPOINT_DEBUG
CONTAINER_CREATE_OPTS	+= $(foreach VAR,$(CONTAINER_VARS),--env "$(VAR)=$($(VAR))")

# Output docker-entrypoint.sh info and debug messages on container start
DOCKER_ENTRYPOINT_INFO	?= yes
DOCKER_ENTRYPOINT_DEBUG	?= yes

# Run commands as user
ifdef CONTAINER_USER
CONTAINER_CREATE_OPTS	+= --user $(CONTAINER_USER)
endif

# Force container removal
CONTAINER_RM_OPTS	+= --force

### COMPOSE_EXECUTOR ###########################################################

# Docker Compose file
ifeq ($(DOCKER_CONFIG),)
COMPOSE_FILES		?= docker-compose.yml
else
COMPOSE_FILES		?= docker-compose.$(DOCKER_CONFIG).yml)
endif
COMPOSE_FILE		?= $(shell echo "$(foreach COMPOSE_FILE,$(COMPOSE_FILES),$(abspath $(PROJECT_DIR)/$(COMPOSE_FILE)))" | tr ' ' ':')

# Docker Compose project name
COMPOSE_NAME_FILE 	?= .docker-compose-name
COMPOSE_NAME		?= $(DOCKER_EXECUTOR_ID)
COMPOSE_PROJECT_NAME	?= $(COMPOSE_NAME)

# Docker Compose service name
COMPOSE_SERVICE_NAME	?= $(shell echo $(DOCKER_NAME) | sed -E -e "s/[^[:alnum:]_]+/_/g")

# Variables used in Docker Compose file
COMPOSE_VARS		+= $(CONTAINER_VARS) \
			   COMPOSE_PROJECT_NAME \
			   COMPOSE_FILE \
			   PROJECT_DIR \
			   BUILD_DIR \
			   TEST_DIR \
			   TEST_ENV_FILE \
			   DOCKER_VARIANT_DIR

# Docker Compose command
COMPOSE_CMD		?= touch $(TEST_ENV_FILE); \
			   export $(foreach DOCKER_VAR,$(COMPOSE_VARS),$(DOCKER_VAR)="$($(DOCKER_VAR))"); \
			   docker-compose

# Docker Compose up options
COMPOSE_UP_OPTS		+= -d --no-build

# Docker Compose down
COMPOSE_RM_OPTS		+= --remove-orphans

### STACK_EXECUTOR #############################################################

# Docker Stack file
ifneq ($(DOCKER_CONFIGS),)
STACK_FILE		?= $(abspath $(PROJECT_DIR)/docker-stack.yml)
else
STACK_FILE		?= $(abspath $(PROJECT_DIR)/docker-stack.$(DOCKER_CONFIG).yml)
endif


# Docker Stack project name
STACK_NAME		?= $(DOCKER_EXECUTOR_ID)

# Docker Compose service name
STACK_SERVICE_NAME	?= $(shell echo $(CONTAINER_NAME_HELPER) | sed -E -e "s/[^[:alnum:]_]+/_/g")

# Variables used in Docker Stack file
STACK_VARS		+= $(COMPOSE_VARS) \
			   $(TEST_VARS) \
			   PROJECT_DIR \
			   BUILD_DIR \
			   TEST_DIR \
			   TEST_ENV_FILE \
			   DOCKER_VARIANT_DIR

# TODO: Docker Swarm Stack executor

### TEST #######################################################################

# Docker test image
TEST_IMAGE_NAME		?= sicz/dockerspec
TEST_IMAGE_TAG		?= latest
TEST_IMAGE		?= $(TEST_IMAGE_NAME):$(TEST_IMAGE_TAG)

# Docker test container name and opts
TEST_CONTAINER_NAME 	?= $(shell \
				echo "$(DOCKER_EXECUTOR_ID)_$(TEST_IMAGE_NAME)" | \
				sed -E "s/[^[:alnum:]_]+/_/g" \
			   )
# Docker Compose/Swarm test service name
TEST_SERVICE_NAME	?= test


# Test conatainer variables
TEST_VARS		+= CONTAINER_NAME \
			   SPEC_OPTS
TEST_CONTAINER_VARS	+= $(CONTAINER_VARS) \
			   $(TEST_VARS)
TEST_COMPOSE_VARS	?= $(COMPOSE_VARS) \
			   $(TEST_VARS) \
			   TEST_CMD
TEST_STACK_VARS		?= $(STACK_VARS) \
			   $(TEST_VARS) \
			   TEST_CMD

# Classic Docer test container variables and options
TEST_CONTAINER_OPTS	+= --interactive \
			   --tty \
			   --name $(TEST_CONTAINER_NAME) \
			   $(foreach VAR,$(TEST_CONTAINER_VARS),--env "$(VAR)=$($(VAR))") \
			   --volume /var/run/docker.sock:/var/run/docker.sock \
			   --volume $(abspath $(TEST_DIR))/.rspec:/root/.rspec \
			   --volume $(abspath $(TEST_DIR))/spec:/root/spec \
			   --workdir /root/$(TEST_DIR) \
			   --rm

# File containing environment variables for the tests
TEST_ENV_FILE		?= $(CURDIR)/.docker-test-env

# Test command
TEST_CMD		?= rspec

# Rspec output format
RSPEC_FORMAT		?= progress
ifneq ($(RSPEC_FORMAT),)
SPEC_OPTS		+= --format $(RSPEC_FORMAT)
endif

# CircleCI configuration file
CIRCLE_CONFIG_FILE	?= $(PROJECT_DIR)/.circleci/config.yml

### SHELL ######################################################################

# Docker shell options and command
SHELL_OPTS		+= --interactive --tty
SHELL_CMD		?= /docker-entrypoint.sh /bin/bash

# Run shell as user
ifdef CONTAINER_USER
SHELL_OPTS		+= --user $(CONTAINER_USER)
endif

### DOCKER_REGISTRY ############################################################

# Docker registry
DOCKER_REGISTRY		?= docker.io

# Tags that will be pushed/pulled to/from Docker repository
DOCKER_PUSH_TAGS	?= $(DOCKER_IMAGE_TAG) $(DOCKER_IMAGE_TAGS)
DOCKER_PULL_TAGS	?= $(DOCKER_PUSH_TAGS)

# Docker image dependencies
DOCKER_IMAGE_DEPENDENCIES += $(BASE_IMAGE)

### DOCKER_VERSION #############################################################

# DOCKER_VERSIONS	?=
DOCKER_VERSION_ALL_TARGETS += docker-pull \
			   docker-pull-images \
			   docker-pull-dependencies \
			   docker-push

################################################################################

# Echo wit -n support
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

MAKE_VARS		?= GITHUB_MAKE_VARS \
			   BASE_IMAGE_MAKE_VARS \
			   DOCKER_IMAGE_MAKE_VARS \
			   BUILD_MAKE_VARS \
			   EXECUTOR_MAKE_VARS \
			   SHELL_MAKE_VARS \
			   DOCKER_REGISTRY_MAKE_VARS \
			   DOCKER_VERSION_MAKE_VARS

define GITHUB_MAKE_VARS
GITHUB_URL:		$(GITHUB_URL)
GITHUB_USER:		$(GITHUB_USER)
GITHUB_REPOSITORY:	$(GITHUB_REPOSITORY)

BUILD_DATE:		$(BUILD_DATE)
VCS_REF:		$(VCS_REF)
endef
export GITHUB_MAKE_VARS

define BASE_IMAGE_MAKE_VARS
BASE_IMAGE_NAME:	$(BASE_IMAGE_NAME)
BASE_IMAGE_TAG:		$(BASE_IMAGE_TAG)
BASE_IMAGE:		$(BASE_IMAGE)
endef
export BASE_IMAGE_MAKE_VARS

define DOCKER_IMAGE_MAKE_VARS
DOCKER_PROJECT:		$(DOCKER_PROJECT)
DOCKER_PROJECT_DESC:	$(DOCKER_PROJECT_DESC)
DOCKER_PROJECT_URL:	$(DOCKER_PROJECT_URL)
DOCKER_NAME:		$(DOCKER_NAME)
DOCKER_IMAGE_TAG:	$(DOCKER_IMAGE_TAG)
DOCKER_IMAGE_TAGS:	$(DOCKER_IMAGE_TAGS)
DOCKER_IMAGE_NAME:	$(DOCKER_IMAGE_NAME)
DOCKER_IMAGE:		$(DOCKER_IMAGE)
DOCKER_FILE		$(DOCKER_FILE)
endef
export DOCKER_IMAGE_MAKE_VARS

define BUILD_MAKE_VARS
CURDIR:			$(CURDIR)
PROJECT_DIR:		$(PROJECT_DIR)

BUILD_DIR:		$(BUILD_DIR)
BUILD_DOCKER_FILE:	$(BUILD_DOCKER_FILE)
BUILD_VARS:		$(BUILD_VARS)
BUILD_OPTS:		$(BUILD_OPTS)
endef
export BUILD_MAKE_VARS

define EXECUTOR_COMMON
DOCKER_EXECUTOR:	$(DOCKER_EXECUTOR)
DOCKER_EXECUTOR_ID_FILE: $(DOCKER_EXECUTOR_ID_FILE)
DOCKER_EXECUTOR_ID:	$(DOCKER_EXECUTOR_ID)

DOCKER_CONFIGS:		$(DOCKER_CONFIGS)
DOCKER_CONFIG:		$(DOCKER_CONFIG)
DOCKER_CONFIG_FILE:	$(DOCKER_CONFIG_FILE)

DOCKER_CONFIG_TARGET:	$(DOCKER_CONFIG_TARGET)
DOCKER_START_TARGET:	$(DOCKER_START_TARGET)
DOCKER_PS_TARGET:	$(DOCKER_PS_TARGET)
DOCKER_LOGS_TARGET:	$(DOCKER_LOGS_TARGET)
DOCKER_LOGS_TAIL_TARGET: $(DOCKER_LOGS_TAIL_TARGET)
DOCKER_TEST_TARGET:	$(DOCKER_TEST_TARGET)
DOCKER_STOP_TARGET:	$(DOCKER_STOP_TARGET)
DOCKER_DESTROY_TARGET:	$(DOCKER_DESTROY_TARGET)
endef
export EXECUTOR_COMMON

ifeq ($(DOCKER_EXECUTOR),container)
define EXECUTOR_MAKE_VARS
$(EXECUTOR_COMMON)

CONTAINER_NAME:		$(CONTAINER_NAME)
CONTAINER_USER:		$(CONTAINER_USER)
CONTAINER_CMD:		$(CONTAINER_CMD)
CONTAINER_VARS:		$(CONTAINER_VARS)
CONTAINER_CREATE_OPTS:	$(CONTAINER_CREATE_OPTS)
CONTAINER_START_OPTS:	$(CONTAINER_START_OPTS)
CONTAINER_PS_OPTS:	$(CONTAINER_PS_OPTS)
CONTAINER_LOGS_OPTS:	$(CONTAINER_LOGS_OPTS)
CONTAINER_STOP_OPTS:	$(CONTAINER_STOP_OPTS)
CONTAINER_RM_OPTS:	$(CONTAINER_RM_OPTS)

TEST_DIR:		$(TEST_DIR)
TEST_IMAGE_NAME:	$(TEST_IMAGE_NAME)
TEST_IMAGE_TAG:		$(TEST_IMAGE_TAG)
TEST_IMAGE:		$(TEST_IMAGE)
TEST_CMD:		$(TEST_CMD)
TEST_CONTAINER_NAME:	$(TEST_CONTAINER_NAME)
TEST_VARS:		$(TEST_VARS)
TEST_CONTAINER_VARS:	$(TEST_CONTAINER_VARS)
TEST_CONTAINER_OPTS:	$(TEST_CONTAINER_OPTS)

RSPEC_FORMAT:		$(RSPEC_FORMAT)
SPEC_OPTS:		$(SPEC_OPTS)
endef
else ifeq ($(DOCKER_EXECUTOR),compose)
define EXECUTOR_MAKE_VARS
$(EXECUTOR_COMMON)

CONTAINER_NAME:		$(CONTAINER_NAME)

COMPOSE_FILES:		$(COMPOSE_FILES)
COMPOSE_FILE:		$(COMPOSE_FILE)
COMPOSE_NAME:		$(COMPOSE_NAME)
COMPOSE_NAME_FILE: 	$(COMPOSE_NAME_FILE)
COMPOSE_PROJECT_NAME:	$(COMPOSE_PROJECT_NAME)
COMPOSE_SERVICE_NAME:	$(COMPOSE_SERVICE_NAME)
COMPOSE_VARS:		$(COMPOSE_VARS)
COMPOSE_CMD:		$(COMPOSE_CMD)
COMPOSE_CONFIG_OPTS: 	$(COMPOSE_CONFIG_OPTS)
COMPOSE_UP_OPTS:	$(COMPOSE_UP_OPTS)
COMPOSE_PS_OPTS:	$(COMPOSE_PS_OPTS)
COMPOSE_LOGS_OPTS: 	$(COMPOSE_LOGS_OPTS)
COMPOSE_STOP_OPTS: 	$(COMPOSE_STOP_OPTS)
COMPOSE_RM_OPTS:	$(COMPOSE_RM_OPTS)

TEST_DIR:		$(TEST_DIR)
TEST_IMAGE_NAME:	$(TEST_IMAGE_NAME)
TEST_IMAGE_TAG:		$(TEST_IMAGE_TAG)
TEST_IMAGE:		$(TEST_IMAGE)
TEST_CMD:		$(TEST_CMD)
TEST_CONTAINER_NAME:	$(TEST_CONTAINER_NAME)
TEST_VARS:		$(TEST_VARS)
TEST_COMPOSE_VARS:	$(TEST_COMPOSE_VARS)
TEST_COMPOSE_CMD:	$(TEST_COMPOSE_CMD)

RSPEC_FORMAT:		$(RSPEC_FORMAT)
SPEC_OPTS:		$(SPEC_OPTS)
endef

else ifeq ($(DOCKER_EXECUTOR),stack)
define EXECUTOR_MAKE_VARS
$(EXECUTOR_COMMON)

CONTAINER_NAME:		$(CONTAINER_NAME)

STACK_FILE:		$(STACK_FILE)
STACK_NAME:		$(STACK_NAME)
STACK_SERVICE_NAME:	$(STACK_SERVICE_NAME)

TEST_DIR:		$(TEST_DIR)
TEST_IMAGE_NAME:	$(TEST_IMAGE_NAME)
TEST_IMAGE_TAG:		$(TEST_IMAGE_TAG)
TEST_IMAGE:		$(TEST_IMAGE)
TEST_CMD:		$(TEST_CMD)
TEST_CONTAINER_NAME:	$(TEST_CONTAINER_NAME)
TEST_VARS:		$(TEST_VARS)
TEST_STACK_VARS:	$(TEST_STACK_VARS)
TEST_STACK_CMD:		$(TEST_STACK_CMD)

RSPEC_FORMAT:		$(RSPEC_FORMAT)
SPEC_OPTS:		$(SPEC_OPTS)
endef
endif
export EXECUTOR_MAKE_VARS

define SHELL_MAKE_VARS
SHELL_OPTS:	$(SHELL_OPTS)
SHELL_CMD:	$(SHELL_CMD)
endef
export SHELL_MAKE_VARS

define DOCKER_REGISTRY_MAKE_VARS
DOCKER_REGISTRY:	$(DOCKER_REGISTRY)
DOCKER_PUSH_TAGS:	$(DOCKER_PUSH_TAGS)
DOCKER_PULL_TAGS:	$(DOCKER_PULL_TAGS)
DOCKER_IMAGE_DEPENDENCIES: $(DOCKER_IMAGE_DEPENDENCIES)
endef
export DOCKER_REGISTRY_MAKE_VARS

define DOCKER_VERSION_MAKE_VARS
DOCKER_VARIANT_DIR:	$(DOCKER_VARIANT_DIR)
DOCKER_VERSIONS:	$(DOCKER_VERSIONS)
DOCKER_VERSION_ALL_TARGETS: $(DOCKER_VERSION_ALL_TARGETS)
endef
export DOCKER_VERSION_MAKE_VARS

### DOCKER_COMMON_TARGETS ######################################################

.PHONY: docker-makevars
docker-makevars:
	@set -eo pipefail; \
	( \
		$(foreach DOCKER_VAR,$(MAKE_VARS), \
			$(ECHO) "$${$(DOCKER_VAR)}"; \
			$(ECHO); \
		) \
	) | sed -E \
		-e $$'s/ +-/\\\n\\\t\\\t\\\t-/g' \
		-e $$'s/ +([A-Z][A-Z]+)/\\\n\\\t\\\t\\\t\\1/g' \
		-e $$'s/(;) */\\1\\\n\\\t\\\t\\\t/g'

.PHONY: docker-set-config
docker-set-config: docker-destroy
	@set -eo pipefail; \
	$(ECHO) $(DOCKER_CONFIG) > $(DOCKER_CONFIG_FILE); \
	$(ECHO) "Setting executor configuration to $(DOCKER_CONFIG)"

# Build Docker image with cached layers
.PHONY: docker-build
docker-build:
	@set -eo pipefail; \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(BUILD_OPTS) -f $(BUILD_DOCKER_FILE) $(BUILD_DIR)

# Build Docker image without cached layers
.PHONY: docker-rebuild
docker-rebuild:
	@set -eo pipefail; \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(BUILD_OPTS) -f $(BUILD_DOCKER_FILE) --no-cache $(BUILD_DIR)

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

# Run shell in the container
.PHONY: docker-shell
docker-shell: docker-start
	@set -eo pipefail; \
	docker exec $(SHELL_OPTS) $(CONTAINER_NAME) $(SHELL_CMD)

# Clean project
.PHONY: docker-clean
docker-clean: docker-stack-destroy docker-compose-destroy docker-container-destroy
	@set -eo pipefail; \
	rm -f .docker-*; \
	find . -type f -name '*~' | xargs rm -f

### DOCKER_EXECUTOR_TARGETS ####################################################

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

# Run tests
.PHONY: docker-test
docker-test: $(DOCKER_TEST_TARGET)
	@true

### CONTAINER_EXECUTOR_TARGET ##################################################

.PHONY: docker-container-config
docker-container-config:
	@true

.PHONY: docker-container-create
docker-container-create:
	@set -eo pipefail; \
	if [ -z "$$(docker container ls --all --quiet --filter 'name=^/$(CONTAINER_NAME)$$')" ]; then \
		$(ECHO) -n "Creating container: "; \
		docker create $(CONTAINER_CREATE_OPTS) --name $(CONTAINER_NAME) $(DOCKER_IMAGE) $(CONTAINER_CMD) > /dev/null; \
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

.PHONY: docker-container-ps
docker-container-ps:
	@set -eo pipefail; \
	docker container ls $(CONTAINER_PS_OPTS) --all --filter 'name=^/$(CONTAINER_NAME)$$'

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

# Run tests
.PHONY: docker-container-test
docker-container-test: docker-container-start
	@set -eo pipefail; \
	rm -f $(TEST_ENV_FILE); \
	$(foreach DOCKER_VAR,$(TEST_CONTAINER_VARS),echo "$(DOCKER_VAR)=$($(DOCKER_VAR))" >> $(TEST_ENV_FILE);) \
	docker run $(TEST_OPTS) $(TEST_IMAGE) $(TEST_CONTAINER_CMD)

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
	CONTAINER_NAMES="$$(docker container ls --all --quiet --filter 'name=^/$(DOCKER_EXECUTOR_ID)_')"; \
	if [ -n "$${CONTAINER_NAMES}" ]; then \
		$(ECHO) -n "Destroying container: "; \
		for CONTAINER_NAME in $${CONTAINER_NAMES}; do \
			docker container rm $(CONTAINER_RM_OPTS) $${CONTAINER_NAME} > /dev/null; \
			$(ECHO) "$${CONTAINER_NAME}"; \
		done; \
	fi

### COMPOSE_EXECUTOR_TARGETS ###################################################

# Display containers configuraion
.PHONY: docker-compose-config
docker-compose-config:
	@set -eo pipefail; \
	$(COMPOSE_CMD) config $(COMPOSE_CONFIG_OPTS)

# Start fresh containers
.PHONY: docker-compose-start
docker-compose-start:
	@set -eo pipefail; \
	$(ECHO) "$(COMPOSE_NAME)" > $(COMPOSE_NAME_FILE); \
	cd $(PROJECT_DIR); \
	$(COMPOSE_CMD) up $(COMPOSE_UP_OPTS) $(COMPOSE_STOP_OPTS) $(COMPOSE_RM_OPTS) $(COMPOSE_SERVICE_NAME)

# List running containers
.PHONY: docker-compose-ps
docker-compose-ps:
	@set -eo pipefail; \
	$(COMPOSE_CMD) ps $(COMPOSE_PS_OPTS); \

# Display containers logs
.PHONY: docker-compose-logs
docker-compose-logs:
	@set -eo pipefail; \
	if [ -e "$(COMPOSE_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) logs $(COMPOSE_LOGS_OPTS); \
	fi

# Follow container logs
.PHONY: docker-compose-logs-tail
docker-compose-logs-tail:
	-@set -eo pipefail; \
	if [ -e "$(COMPOSE_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) logs --follow $(COMPOSE_LOGS_OPTS); \
	fi

# Run tests
.PHONY: docker-compose-test
docker-compose-test: docker-compose-start
	@set -eo pipefail; \
	$(ECHO) -n > $(TEST_ENV_FILE); \
	$(foreach VAR,$(COMPOSE_VARS),echo "$(VAR)=$($(VAR))" >> $(TEST_ENV_FILE);) \
	$(COMPOSE_CMD) run --no-deps --rm $(TEST_SERVICE_NAME) $(TEST_CMD)

# Stop containers
.PHONY: docker-compose-stop
docker-compose-stop:
	@set -eo pipefail; \
	if [ -e "$(COMPOSE_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) stop $(COMPOSE_STOP_OPTS); \
	fi

# Destroy containers
.PHONY: docker-compose-destroy
docker-compose-destroy:
	@set -eo pipefail; \
	if [ -e "$(COMPOSE_NAME_FILE)" ]; then \
		$(COMPOSE_CMD) down $(COMPOSE_RM_OPTS); \
		rm -f "$(COMPOSE_NAME_FILE)"; \
	fi

### STACK_EXECUTOR_TARGETS #####################################################

# Display stack configuraion
.PHONY: docker-stack-config
docker-stack-config: docker-compose-config

# Start fresh stack
.PHONY: docker-stack-start
docker-stack-start:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# List running services
.PHONY: docker-stack-ps
docker-stack-ps:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Display stack service logs
.PHONY: docker-stack-logs
docker-stack-logs:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Follow stack service logs
.PHONY: docker-stack-logs-tail
docker-stack-logs-tail:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Run tests
.PHONY: docker-stack-test
docker-stack-test: docker-stack-start $(TEST_ENV_FILE)
# TODO: Docker Swarm Stack executor
	@set -eo pipefail; \
	rm -f $(TEST_ENV_FILE); \
	$(foreach VAR,$(STACK_VARS),echo "$(VAR)=$($(VAR))" >> $(TEST_ENV_FILE);) \
	$(error Docker executor "stack" is not yet implemented)

# Stop stack
.PHONY: docker-stack-stop
docker-stack-stop:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Destroy stack
.PHONY: docker-stack-destroy
docker-stack-destroy:
# TODO: Docker Swarm Stack executor
#	$(error Docker executor "stack" is not yet implemented)
	@true

### DOCKER_REGISTRY_TARGETS ####################################################

# Pull all images from Docker Registry
.PHONY: docker-pull
docker-pull: docker-pull-dependencies docker-pull-image docker-pull-testimage

# Pull project images dependencies from Docker registry
.PHONY: docker-pull-dependencies
docker-pull-dependencies:
	@set -eo pipefail; \
	$(foreach DOCKER_IMAGE,$(DOCKER_IMAGE_DEPENDENCIES),docker pull $(DOCKER_IMAGE);echo;)

# Pull project images from Docker registry
.PHONY: docker-pull-image
docker-pull-image:
	@set -eo pipefail; \
	$(foreach TAG,$(DOCKER_PULL_TAGS),docker pull $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);echo;)

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


### DOCKER_VERSION_TARGETS #####################################################

# Make $(DOCKER_TARGET) in sll $(DOCKER_VERSIONS)
.PHONY: docker-all
docker-all:
	@set -eo pipefail; \
	for DOCKER_VERSION in $(DOCKER_VERSIONS); do \
		cd $(abspath $(DOCKER_VARIANT_DIR))/$${DOCKER_VERSION}; \
		if [ "$${DOCKER_VERSION}" = "." ]; then \
			DOCKER_VERSION="latest"; \
		fi; \
		$(ECHO); \
		$(ECHO); \
		$(ECHO) "===> $(DOCKER_NAME):$${DOCKER_VERSION}"; \
		$(ECHO); \
		$(ECHO); \
		$(MAKE) $(DOCKER_TARGET); \
	done

# Create $(DOCKER_VERSION_ALL_TARGETS)-all targets
# DOCKER_ALL_TARGET:
# $1 - <TARGET>
define DOCKER_ALL_TARGET
.PHONY: $(1)-all
$(1)-all: ; @set -eo pipefail; $(MAKE) docker-all DOCKER_TARGET=$(1)
endef
$(foreach DOCKER_TARGET,$(DOCKER_VERSION_ALL_TARGETS),$(eval $(call DOCKER_ALL_TARGET,$(DOCKER_TARGET))))

### CIRCLE_CI ##################################################################

# Update Dockerspec tag in CircleCI configuration
.PHONY: ci-update-config
ci-update-config: docker-pull-testimage
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
