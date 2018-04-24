### SHELL ######################################################################

# Replace Debian Almquist Shell with Bash
ifeq ($(realpath $(SHELL)),/bin/dash)
SHELL   		:= /bin/bash
endif

# Exit immediately if a command exits with a non-zero exit status
# TODO: .SHELLFLAGS does not exists on obsoleted macOS X-Code make
# .SHELLFLAGS		= -ec
SHELL			+= -e

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

GITHUB_USER		?= $(notdir $(shell dirname $(GITHUB_URL)))
GITHUB_REPOSITORY	?= $(notdir $(GITHUB_URL))

# All modifications are commited
ifeq ($(shell git status --porcelain),)
GIT_REVISION		?= $(shell git rev-parse --short HEAD)
# Modifications are not commited
else
GIT_REVISION		?= $(shell git rev-parse --short HEAD)-devel
endif

# Build date
BUILD_DATE		?= $(shell date -u "+%Y-%m-%dT%H:%M:%SZ")

### PROJECT_DIRS ###############################################################

# Project directories
PROJECT_DIR		?= $(CURDIR)
BUILD_DIR		?= $(PROJECT_DIR)
TEST_DIR		?= $(BUILD_DIR)
VARIANT_DIR		?= $(BUILD_DIR)
DOCKER_IMAGE_DEPOT	?= $(PROJECT_DIR)

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
BUILD_DOCKER_FILE	?= $(abspath $(VARIANT_DIR)/$(DOCKER_FILE))

# Build image with tags
BUILD_OPTS		+= --tag $(DOCKER_IMAGE) \
			   $(foreach TAG,$(DOCKER_IMAGE_TAGS),--tag $(DOCKER_IMAGE_NAME):$(TAG)) \
			   --label org.opencontainers.image.title="$(DOCKER_IMAGE_NAME)" \
			   --label org.opencontainers.image.version="$(DOCKER_IMAGE_TAG)" \
			   --label org.opencontainers.image.description="$(DOCKER_PROJECT_DESC)" \
			   --label org.opencontainers.image.url="$(DOCKER_PROJECT_URL)" \
			   --label org.opencontainers.image.source="$(GITHUB_URL)"

# Docker Layer Caching
DOCKER_IMAGE_ID		= $(shell docker inspect --format '{{.Id}}' $(DOCKER_IMAGE) 2> /dev/null)
ifneq ($(DOCKER_IMAGE_ID),)
DOCKER_IMAGE_CREATED	= $(shell docker inspect --format '{{index .Config.Labels "org.opencontainers.image.created"}}' $(DOCKER_IMAGE))
DOCKER_IMAGE_REVISION	= $(shell docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' $(DOCKER_IMAGE))
BUILD_OPTS		+= --cache-from $(DOCKER_IMAGE)
else
DOCKER_IMAGE_CREATED	= $(BUILD_DATE)
DOCKER_IMAGE_REVISION	= $(GIT_REVISION)
endif
BUILD_OPTS		+= --label org.opencontainers.image.created=$(DOCKER_IMAGE_CREATED) \
			   --label org.opencontainers.image.revision=$(DOCKER_IMAGE_REVISION)

# Use http proxy when building the image
ifdef HTTP_PROXY
BUILD_OPTS		+= --build-arg HTTP_PROXY=$(http_proxy)
else ifdef http_proxy
BUILD_OPTS		+= --build-arg HTTP_PROXY=$(HTTP_PROXY)
endif

# Docker image build variables
BUILD_OPTS		+= $(foreach VAR,$(BUILD_VARS),--build-arg "$(VAR)=$($(VAR))")
override BUILD_VARS	+= BASE_IMAGE \
			   BASE_IMAGE_NAME \
			   BASE_IMAGE_TAG \
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
			   GITHUB_USER

#### DOCKER_EXECUTOR ###########################################################

# Docker executor type:
# container - classic Docker container
# compose - Docker Compose service
# stack - Docker Swarm stack
DOCKER_EXECUTOR		?= container

# Hi-level targets for creating and starting containers
CREATE_TARGET		?= create
START_TARGET		?= start
RM_TARGET		?= rm

# Unique project id
DOCKER_EXECUTOR_ID_FILE	?= .docker-executor-id
DOCKER_EXECUTOR_ID	?= $(shell \
				if [ -e $(DOCKER_EXECUTOR_ID_FILE) ]; then \
					cat $(DOCKER_EXECUTOR_ID_FILE); \
				else \
					openssl rand -hex 4; \
				fi \
			   )

# Support multiple configurations of the Docker executor
ifneq ($(DOCKER_CONFIGS),)
DOCKER_CONFIG_FILE	?= .docker-executor-config
DOCKER_CONFIG		?= $(shell \
				if [ -e $(DOCKER_CONFIG_FILE) ]; then \
					cat $(DOCKER_CONFIG_FILE); \
				else \
					echo "default"; \
				fi \
			   )
endif

### CONTAINER_EXECUTOR #########################################################

# Docker service name
SERVICE_NAME		?= $(shell echo $(DOCKER_NAME) | sed -E -e "s/[^[:alnum:]_]+/_/g")

# Wait service name
WAIT_SERVICE_NAME	?= wait

# Docker container name
ifeq ($(DOCKER_EXECUTOR),container)
CONTAINER_NAME		?= $(DOCKER_EXECUTOR_ID)_$(SERVICE_NAME)
TEST_CONTAINER_NAME	?= $(DOCKER_EXECUTOR_ID)_$(TEST_SERVICE_NAME)
else ifeq ($(DOCKER_EXECUTOR),compose)
CONTAINER_NAME		?= $(DOCKER_EXECUTOR_ID)_$(COMPOSE_SERVICE_NAME)_1
TEST_CONTAINER_NAME	?= $(DOCKER_EXECUTOR_ID)_$(TEST_SERVICE_NAME)_1
else ifeq ($(DOCKER_EXECUTOR),stack)
# TODO: Docker Swarm Stack executor
CONTAINER_NAME		?= $(DOCKER_EXECUTOR_ID)_$(STACK_SERVICE_NAME)_1
TEST_CONTAINER_NAME	?= $(DOCKER_EXECUTOR_ID)_$(TEST_SERVICE_NAME)_1
else
$(error Unknown Docker executor "$(DOCKER_EXECUTOR)")
endif

# Variables available in the running container
override CONTAINER_VARS	+= $(BUILD_VARS)
CONTAINER_CREATE_OPTS	+= $(foreach VAR,$(CONTAINER_VARS),--env "$(VAR)=$($(VAR))") \
			  --name $(CONTAINER_NAME)

# Run command as a user
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
COMPOSE_FILES		?= docker-compose.yml \
			   docker-compose.$(DOCKER_CONFIG).yml
endif
COMPOSE_FILE		?= $(shell echo "$(foreach COMPOSE_FILE,$(COMPOSE_FILES),$(abspath $(PROJECT_DIR)/$(COMPOSE_FILE)))" | tr ' ' ':')

# Docker Compose project name
COMPOSE_NAME		?= $(DOCKER_EXECUTOR_ID)
COMPOSE_PROJECT_NAME	?= $(COMPOSE_NAME)

# Docker Compose service name
COMPOSE_SERVICE_NAME	?= $(SERVICE_NAME)

# Variables used in the Docker Compose file
override COMPOSE_VARS	+= $(CONTAINER_VARS) \
			   COMPOSE_PROJECT_NAME \
			   COMPOSE_FILE \
			   PROJECT_DIR \
			   BUILD_DIR \
			   CURDIR \
			   TEST_CMD \
			   TEST_DIR \
			   TEST_ENV_FILE \
			   TEST_IMAGE \
			   TEST_PROJECT_DIR \
			   VARIANT_DIR

# Docker Compose command
COMPOSE_CMD		?= touch $(TEST_ENV_FILE); \
			   export $(foreach DOCKER_VAR,$(COMPOSE_VARS),$(DOCKER_VAR)="$($(DOCKER_VAR))"); \
			   docker-compose

# Docker Compose create options
COMPOSE_CREATE_OPTS	+= --no-build

# Docker Compose up options
COMPOSE_UP_OPTS		+= -d --remove-orphans $(COMPOSE_CREATE_OPTS)

# Docker Compose down options
COMPOSE_RM_OPTS		+= --remove-orphans -v

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
STACK_SERVICE_NAME	?= $(SERVICE_NAME)

# Variables used in the Docker Stack file
override STACK_VARS	+= $(STACK_VARS) \
			   $(TEST_VARS) \
			   PROJECT_DIR \
			   BUILD_DIR \
			   CURDIR \
			   TEST_DIR \
			   TEST_ENV_FILE \
			   TEST_IMAGE \
			   VARIANT_DIR

# TODO: Docker Swarm Stack executor

### TEST #######################################################################

# Docker test image
TEST_IMAGE_NAME		?= sicz/dockerspec
TEST_IMAGE_TAG		?= latest
TEST_IMAGE		?= $(TEST_IMAGE_NAME):$(TEST_IMAGE_TAG)

# Docker Compose/Swarm test service name
TEST_SERVICE_NAME	?= test

# Variables used in the test conatainer
override TEST_VARS	+= CONTAINER_NAME \
			   SPEC_OPTS
TEST_CONTAINER_VARS	?= $(CONTAINER_VARS) \
			   $(TEST_VARS)
TEST_COMPOSE_VARS	?= $(COMPOSE_VARS) \
			   $(TEST_VARS) \
			   TEST_CMD
TEST_STACK_VARS		?= $(STACK_VARS) \
			   $(TEST_VARS) \
			   TEST_CMD

# Classic Docker test container options
TEST_CONTAINER_OPTS	+= --interactive \
			   --tty \
			   --name $(TEST_CONTAINER_NAME) \
			   $(foreach VAR,$(TEST_CONTAINER_VARS),--env "$(VAR)=$($(VAR))") \
			   --volume /var/run/docker.sock:/var/run/docker.sock \
			   --volume $(abspath $(TEST_DIR))/.rspec:/root/.rspec \
			   --volume $(abspath $(TEST_DIR))/spec:/root/spec \
			   --workdir /root/$(TEST_DIR) \
			   --rm

# File containing environment variables
TEST_ENV_FILE		?= $(CURDIR)/.docker-$(DOCKER_EXECUTOR)-test-env

# Use the project dir as the host volume if Docker host is local
ifeq ($(DOCKER_HOST),)
TEST_PROJECT_DIR	?= $(PROJECT_DIR)
endif

# Test command
TEST_CMD		?= rspec

# Rspec output format
# RSPEC_FORMAT		?= documentation
ifneq ($(RSPEC_FORMAT),)
override SPEC_OPTS	+= --format $(RSPEC_FORMAT)
endif

# Allow RSpec colorized output without allocated tty
ifeq ($(DOCKER_HOST),)
override SPEC_OPTS	+= --tty
endif

# CircleCI configuration file
CIRCLECI_CONFIG_FILE	?= $(PROJECT_DIR)/.circleci/config.yml

### SHELL ######################################################################

# Docker shell options and command
SHELL_OPTS		+= --interactive --tty
SHELL_CMD		?= /docker-entrypoint.sh /bin/bash --login

# Run the shell as an user
ifdef CONTAINER_USER
SHELL_OPTS		+= --user $(CONTAINER_USER)
endif

### DOCKER_REGISTRY ############################################################

# Docker registry
DOCKER_REGISTRY		?= docker.io

# Tags that will be pushed/pulled to/from Docker repository
DOCKER_PUSH_TAGS	?= $(DOCKER_IMAGE_TAG) $(DOCKER_IMAGE_TAGS)
DOCKER_PULL_TAGS	?= $(DOCKER_PUSH_TAGS)

### DOCKER_VERSION #############################################################

# Make targets propagated to all Docker image versions
DOCKER_ALL_VERSIONS_TARGETS += docker-pull \
			   docker-pull-image \
			   docker-pull-dependencies \
			   docker-pull-testimage \
			   docker-push

################################################################################

# Echo with -n support
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

# Display the make variables
MAKE_VARS		?= GITHUB_MAKE_VARS \
			   BASE_IMAGE_MAKE_VARS \
			   DOCKER_IMAGE_MAKE_VARS \
			   BUILD_MAKE_VARS \
			   EXECUTOR_MAKE_VARS \
			   SHELL_MAKE_VARS \
			   DOCKER_REGISTRY_MAKE_VARS

define GITHUB_MAKE_VARS
GITHUB_URL:		$(GITHUB_URL)
GITHUB_USER:		$(GITHUB_USER)
GITHUB_REPOSITORY:	$(GITHUB_REPOSITORY)

BUILD_DATE:		$(BUILD_DATE)
GIT_REVISION:		$(GIT_REVISION)
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
endef
export DOCKER_IMAGE_MAKE_VARS

define BUILD_MAKE_VARS
CURDIR:			$(CURDIR)
PROJECT_DIR:		$(PROJECT_DIR)

DOCKER_FILE:		$(DOCKER_FILE)
VARIANT_DIR:		$(VARIANT_DIR)
BUILD_DOCKER_FILE:	$(BUILD_DOCKER_FILE)
BUILD_DIR:		$(BUILD_DIR)
BUILD_VARS:		$(BUILD_VARS)
BUILD_OPTS:		$(BUILD_OPTS)
endef
export BUILD_MAKE_VARS

define EXECUTOR_COMMON
DOCKER_EXECUTOR:	$(DOCKER_EXECUTOR)
DOCKER_EXECUTOR_ID:	$(DOCKER_EXECUTOR_ID)
DOCKER_EXECUTOR_ID_FILE: $(DOCKER_EXECUTOR_ID_FILE)

DOCKER_CONFIGS:		$(DOCKER_CONFIGS)
DOCKER_CONFIG:		$(DOCKER_CONFIG)
DOCKER_CONFIG_FILE:	$(DOCKER_CONFIG_FILE)

CREATE_TARGET:		$(CREATE_TARGET)
START_TARGET:		$(START_TARGET)
RM_TARGET:		$(RM_TARGET)

SERVICE_NAME:		$(SERVICE_NAME)
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

TEST_IMAGE_NAME:	$(TEST_IMAGE_NAME)
TEST_IMAGE_TAG:		$(TEST_IMAGE_TAG)
TEST_IMAGE:		$(TEST_IMAGE)
TEST_DIR:		$(TEST_DIR)
TEST_SERVICE_NAME:	$(TEST_SERVICE_NAME)
TEST_CONTAINER_NAME:	$(TEST_CONTAINER_NAME)
TEST_VARS:		$(TEST_VARS)
TEST_CONTAINER_VARS:	$(TEST_CONTAINER_VARS)
TEST_CONTAINER_OPTS:	$(TEST_CONTAINER_OPTS)

TEST_CMD:		$(TEST_CMD)
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

CIRCLECI:		$(CIRCLECI)
TEST_IMAGE_NAME:	$(TEST_IMAGE_NAME)
TEST_IMAGE_TAG:		$(TEST_IMAGE_TAG)
TEST_IMAGE:		$(TEST_IMAGE)
TEST_DIR:		$(TEST_DIR)
TEST_ENV_FILE:		$(TEST_ENV_FILE)
TEST_SERVICE_NAME:	$(TEST_SERVICE_NAME)
TEST_CONTAINER_NAME:	$(TEST_CONTAINER_NAME)
TEST_VARS:		$(TEST_VARS)
TEST_COMPOSE_VARS:	$(TEST_COMPOSE_VARS)

TEST_CMD:		$(TEST_CMD)
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

TEST_IMAGE_NAME:	$(TEST_IMAGE_NAME)
TEST_IMAGE_TAG:		$(TEST_IMAGE_TAG)
TEST_IMAGE:		$(TEST_IMAGE)
TEST_DIR:		$(TEST_DIR)
TEST_ENV_FILE:		$(TEST_ENV_FILE)
TEST_SERVICE_NAME:	$(TEST_SERVICE_NAME)
TEST_CONTAINER_NAME:	$(TEST_CONTAINER_NAME)
TEST_VARS:		$(TEST_VARS)
TEST_STACK_VARS:	$(TEST_STACK_VARS)
TEST_STACK_CMD:		$(TEST_STACK_CMD)

TEST_CMD:		$(TEST_CMD)
RSPEC_FORMAT:		$(RSPEC_FORMAT)
SPEC_OPTS:		$(SPEC_OPTS)
endef
endif
export EXECUTOR_MAKE_VARS

define SHELL_MAKE_VARS
SHELL_OPTS:		$(SHELL_OPTS)
SHELL_CMD:		$(SHELL_CMD)
endef
export SHELL_MAKE_VARS

define DOCKER_REGISTRY_MAKE_VARS
DOCKER_REGISTRY:	$(DOCKER_REGISTRY)
DOCKER_PUSH_TAGS:	$(DOCKER_PUSH_TAGS)
DOCKER_PULL_TAGS:	$(DOCKER_PULL_TAGS)
DOCKER_IMAGE_DEPENDENCIES: $(DOCKER_IMAGE_DEPENDENCIES)
endef
export DOCKER_REGISTRY_MAKE_VARS

### BUILD_TARGETS ##############################################################

# Build a new image with using the Docker layer caching
.PHONY: docker-build
docker-build:
	@set -eo pipefail; \
	$(ECHO) "Building image $(DOCKER_IMAGE)"; \
	docker build $(BUILD_OPTS) -f $(BUILD_DOCKER_FILE) $(BUILD_DIR); \
	BUILD_ID="`docker inspect --format '{{.Id}}' $(DOCKER_IMAGE)`"; \
	if [ -n "$(DOCKER_IMAGE_ID)" -a "$(DOCKER_IMAGE_ID)" != "$${BUILD_ID}" ]; then \
		$(ECHO) "Image changed, building with current labels"; \
		docker build $(BUILD_OPTS) \
			--label org.opencontainers.image.created=$(BUILD_DATE) \
			--label org.opencontainers.image.revision=$(GIT_REVISION) \
			-f $(BUILD_DOCKER_FILE) $(BUILD_DIR); \
	fi

# Build a new image without using the Docker layer caching
.PHONY: docker-rebuild
docker-rebuild:
	@set -eo pipefail; \
	$(ECHO) "Rebuilding image $(DOCKER_IMAGE)"; \
	docker build $(BUILD_OPTS) \
		--label org.opencontainers.image.created=$(BUILD_DATE) \
		--label org.opencontainers.image.revision=$(GIT_REVISION) \
		-f $(BUILD_DOCKER_FILE) --no-cache $(BUILD_DIR)

# Tag the Docker image
.PHONY: docker-tag
docker-tag:
ifneq ($(DOCKER_IMAGE_TAGS),)
	@$(ECHO) "Tagging image with tags $(DOCKER_IMAGE_TAGS)"
	@$(foreach TAG,$(DOCKER_IMAGE_TAGS), \
		docker tag $(DOCKER_IMAGE) $(DOCKER_IMAGE_NAME):$(TAG); \
	)
endif

### EXECUTOR_TARGETS ###########################################################

# Display the Docker image version
.PHONY: display-version-header
display-version-header:
	@$(ECHO)
	@$(ECHO) "===> $(DOCKER_IMAGE)"
	@$(ECHO)

# Save the Docker executor id
$(DOCKER_EXECUTOR_ID_FILE):
	@$(ECHO) $(DOCKER_EXECUTOR_ID) > $(DOCKER_EXECUTOR_ID_FILE)

# Display the current configuration name
.PHONY: display-executor-config
display-executor-config:
ifneq ($(DOCKER_CONFIGS),)
	@$(ECHO) "Using $(DOCKER_CONFIG) configuration with $(DOCKER_EXECUTOR) executor"
endif

# Display the configuration file
.PHONY: diplay-config-file
display-config-file: display-$(DOCKER_EXECUTOR)-config-file
	@true

# Display the make variables
.PHONY: display-makevars
display-makevars: display-executor-config
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

# Set the Docker executor configuration
.PHONY: set-executor-config
set-executor-config: $(RM_TARGET)
ifneq ($(DOCKER_CONFIGS),)
ifeq ($(filter $(DOCKER_CONFIG),$(DOCKER_CONFIGS)),)
	$(error Unsupported Docker executor configuration "$(DOCKER_CONFIG)")
endif
	@$(ECHO) $(DOCKER_CONFIG) > $(DOCKER_CONFIG_FILE)
	@$(ECHO) "Setting executor configuration to $(DOCKER_CONFIG)"
else
	$(error Docker executor does not support multiple configs)
endif

# Remove the containers and then run them fresh
.PHONY: docker-up
docker-up:
	@$(MAKE) $(RM_TARGET) $(START_TARGET)

# Create the containers
.PHONY: docker-create
docker-create: $(DOCKER_EXECUTOR_ID_FILE) display-executor-config docker-$(DOCKER_EXECUTOR)-create
	@true

# Start the containers
.PHONY: docker-start
docker-start: display-executor-config docker-$(DOCKER_EXECUTOR)-start
	@true

# Wait for the start of the containers
.PHONY: docker-wait
docker-wait: docker-$(DOCKER_EXECUTOR)-wait
	@true

# Display running containers
.PHONY: docker-ps
docker-ps: docker-$(DOCKER_EXECUTOR)-ps
	@true

# Display the containers logs
.PHONY: docker-logs
docker-logs: docker-$(DOCKER_EXECUTOR)-logs
	@true

# Follow the containers logs
.PHONY: docker-logs-tail
docker-logs-tail: docker-$(DOCKER_EXECUTOR)-logs-tail
	@true

# Run the shell in the running container
.PHONY: docker-shell
docker-shell: $(START_TARGET)
	@set -eo pipefail; \
	docker exec $(SHELL_OPTS) $(CONTAINER_NAME) $(SHELL_CMD)

# Run the tests
.PHONY: docker-test
docker-test: display-executor-config docker-$(DOCKER_EXECUTOR)-test
	@true

# Stop the containers
.PHONY: docker-stop
docker-stop: docker-$(DOCKER_EXECUTOR)-stop
	@true

# Remove the containers
.PHONY: docker-rm
docker-rm: docker-$(DOCKER_EXECUTOR)-rm
	@true

# Remove all containers and work files
.PHONY: docker-clean
docker-clean: docker-stack-rm docker-compose-rm docker-container-rm
	@rm -f .docker-* $(DOCKER_IMAGE_DEPOT)/$(DOCKER_PROJECT)-$(DOCKER_NAME)-$(DOCKER_IMAGE_TAG).image
	@find . -type f -name '*~' | xargs rm -f

### CONTAINER_EXECUTOR_TARGET ##################################################

# Display the configuration file
.PHONY: display-container-config-file
display-container-config-file:
	@$(MAKE) display-makevars MAKE_VARS="$(DOCKER_EXECUTOR_MAKE_VARS)"

# Create the container
.PHONY: docker-container-create
docker-container-create: .docker-container-create
	@true

.docker-container-create:
	@$(ECHO) "Creating container $(CONTAINER_NAME)"
	@docker container create $(CONTAINER_CREATE_OPTS) $(DOCKER_IMAGE) $(CONTAINER_CMD) > /dev/null
	@$(ECHO) $(DOCKER_IMAGE) > $@

# Start the container
.PHONY: docker-container-start
docker-container-start: .docker-container-start
	@true

.docker-container-start: $(CREATE_TARGET)
	@$(ECHO) "Starting container $(CONTAINER_NAME)"
	@docker container start $(CONTAINER_START_OPTS) $(CONTAINER_NAME) > /dev/null
	@$(ECHO) $(CONTAINER_NAME) > $@

# Wait for the start of the container
.PHONY: docker-container-wait
docker-container-wait: $(START_TARGET)
	@$(ECHO) "Waiting for container $(CONTAINER_NAME)"
	@docker container run $(TEST_CONTAINER_OPTS) $(TEST_IMAGE) true

# Display running containers
.PHONY: docker-container-ps
docker-container-ps:
	@docker container ls $(CONTAINER_PS_OPTS) --all --filter 'name=^/$(CONTAINER_NAME)$$'

# Display the container logs
.PHONY: docker-container-logs
docker-container-logs:
	@if [ -e .docker-container-start ]; then \
		docker container logs $(CONTAINER_LOGS_OPTS) $(CONTAINER_NAME); \
	fi

# Follow the container logs
.PHONY: docker-container-logs-tail
docker-container-logs-tail:
	@if [ -e .docker-container-start ]; then \
		docker container logs --follow $(CONTAINER_LOGS_OPTS) $(CONTAINER_NAME); \
	fi

# Run the tests
.PHONY: docker-container-test
docker-container-test: $(START_TARGET)
	@$(ECHO) "Running container $(CONTAINER_NAME)"
	@docker container run $(TEST_CONTAINER_OPTS) $(TEST_IMAGE) $(TEST_CMD)

# Stop the container
.PHONY: docker-container-stop
docker-container-stop:
	@if [ -e .docker-container-start ]; then \
		$(ECHO) -n "Stopping container $(CONTAINER_NAME)"; \
		docker container stop $(CONTAINER_STOP_OPTS) $(CONTAINER_NAME) > /dev/null; \
	fi

# Remove the container
.PHONY: docker-container-rm
docker-container-rm: docker-container-stop
	@set -eo pipefail; \
	 CONTAINER_NAMES="$$(docker container ls --all --quiet --filter 'name=^/$(DOCKER_EXECUTOR_ID)_')"; \
	 if [ -n "$${CONTAINER_NAMES}" ]; then \
		$(ECHO) -n "Removing container "; \
		for CONTAINER_NAME in $${CONTAINER_NAMES}; do \
			docker container rm $(CONTAINER_RM_OPTS) $${CONTAINER_NAME} > /dev/null; \
			$(ECHO) "$${CONTAINER_NAME}"; \
		done; \
	 fi
	@rm -f .docker-container-*

### COMPOSE_EXECUTOR_TARGETS ###################################################

# Display the configuration file
.PHONY: display-compose-config-file
display-compose-config-file:
	@$(COMPOSE_CMD) config $(COMPOSE_CONFIG_OPTS)

# Create the containers
.PHONY: docker-compose-create
docker-compose-create: .docker-compose-create

.docker-compose-create:
	@cd $(PROJECT_DIR) && \
	 $(COMPOSE_CMD) up --no-start $(COMPOSE_CREATE_OPTS) $(COMPOSE_SERVICE_NAME)
	@$(ECHO) $(COMPOSE_SERVICE_NAME) > $@

# Start the containers
.PHONY: docker-compose-start
docker-compose-start: .docker-compose-start

.docker-compose-start: $(CREATE_TARGET)
	@$(COMPOSE_CMD) up $(COMPOSE_UP_OPTS) $(COMPOSE_SERVICE_NAME)
	@$(ECHO) $(COMPOSE_SERVICE_NAME) > $@

# Wait for the start of the containers
.PHONY: docker-compose-wait
docker-compose-wait: $(START_TARGET)
	@$(ECHO) "Waiting for container $(CONTAINER_NAME)"
	@set +e; \
	$(COMPOSE_CMD) run --rm $(WAIT_SERVICE_NAME) true; \
	if [ $$? != 0 ]; then \
		$(COMPOSE_CMD) logs $(COMPOSE_LOGS_OPTS); \
		$(ECHO) "ERROR: Timeout has just expired" >&2; \
		exit 1; \
	fi

# Display running containers
.PHONY: docker-compose-ps
docker-compose-ps:
	@$(COMPOSE_CMD) ps $(COMPOSE_PS_OPTS)

# Display the containers logs
.PHONY: docker-compose-logs
docker-compose-logs:
	@if [ -e .docker-compose-start ]; then \
		$(COMPOSE_CMD) logs $(COMPOSE_LOGS_OPTS); \
	fi

# Follow the containers logs
.PHONY: docker-compose-logs-tail
docker-compose-logs-tail:
	@if [ -e .docker-compose-start ]; then \
		$(COMPOSE_CMD) logs --follow $(COMPOSE_LOGS_OPTS); \
	fi

# Run the tests
.PHONY: docker-compose-test
docker-compose-test: $(START_TARGET) .docker-compose-test
	@$(ECHO) "Running tests in container $(TEST_CONTAINER_NAME)"
	@$(COMPOSE_CMD) run --rm $(TEST_SERVICE_NAME) $(TEST_CMD)

.docker-compose-test:
	@$(ECHO) "Creating container $(TEST_CONTAINER_NAME)"
	@rm -f $(TEST_ENV_FILE)
	@$(foreach VAR,$(TEST_COMPOSE_VARS),echo "$(VAR)=$($(VAR))" >> $(TEST_ENV_FILE);)
	@$(COMPOSE_CMD) up --no-start --no-build $(TEST_SERVICE_NAME)
# Copy the project dir to the test container if the Docker host is remote
ifeq ($(TEST_PROJECT_DIR),)
	@$(ECHO) "Copying project to container $(TEST_CONTAINER_NAME)"
	@docker cp $(PROJECT_DIR) $(TEST_CONTAINER_NAME):$(dir $(PROJECT_DIR))
endif
	@echo $(TEST_SERVICE_NAME) > $@

# Stop the containers
.PHONY: docker-compose-stop
docker-compose-stop:
	@if [ -e .docker-compose-start ]; then \
		$(COMPOSE_CMD) stop $(COMPOSE_STOP_OPTS); \
	fi

# Remove the containers
.PHONY: docker-compose-rm
docker-compose-rm:
	@if [ -e .docker-compose-create ]; then \
		$(COMPOSE_CMD) down $(COMPOSE_RM_OPTS); \
	fi
	@rm -f .docker-compose-*

### STACK_EXECUTOR_TARGETS #####################################################

# Display the configuration file
.PHONY: display-stack-config-file
display-stack-config-file:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Create the stack
.PHONY: docker-stack-create
docker-stack-create: .docker-stack-create
	@true

.docker-stack-create:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)
	@$(ECHO) $(STACK_SERVICE_NAME) > $@

# Start the stack
.PHONY: docker-stack-start
docker-stack-start: .docker-stack-start
	@true

.docker-stack-start: $(CREATE_TARGET)
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)
	@$(ECHO) $(STACK_SERVICE_NAME) > $@

# Wait for the start of the stack
.PHONY: docker-stack-wait
docker-stack-wait: $(START_TARGET)
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Display running services
.PHONY: docker-stack-ps
docker-stack-ps:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Display the service logs
.PHONY: docker-stack-logs
docker-stack-logs:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Follow the service logs
.PHONY: docker-stack-logs-tail
docker-stack-logs-tail:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Run the tests
.PHONY: docker-stack-test
docker-stack-test: $(START_TARGET)
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Stop the stack
.PHONY: docker-stack-stop
docker-stack-stop:
# TODO: Docker Swarm Stack executor
	$(error Docker executor "stack" is not yet implemented)

# Remove the stack
.PHONY: docker-stack-rm
docker-stack-rm:
# TODO: Docker Swarm Stack executor
#	@if [ -e .docker-stack-create ]; then \
#		$(error Docker executor "stack" is not yet implemented); \
#	fi
	@rm -f .docker-stack-*

### DOCKER_REGISTRY_TARGETS ####################################################

# Pull all images from the Docker Registry
.PHONY: docker-pull
docker-pull: docker-pull-dependencies docker-pull-image docker-pull-testimage
	@true

# Pull project base image from the Docker registry
.PHONY: docker-pull-baseimage
docker-pull-baseimage:
	@docker pull $(BASE_IMAGE)

# Pull the project image dependencies from the Docker registry
.PHONY: docker-pull-dependencies
docker-pull-dependencies:
	@$(foreach DOCKER_IMAGE,$(DOCKER_IMAGE_DEPENDENCIES),docker pull $(DOCKER_IMAGE);echo;)

# Pull the project image from the Docker registry
.PHONY: docker-pull-image
docker-pull-image:
	@$(foreach TAG,$(DOCKER_PULL_TAGS),docker pull $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);echo;)

# Pull the test image from the Docker registry
.PHONY: docker-pull-testimage
docker-pull-testimage:
	@docker pull $(TEST_IMAGE)

# Posh the project image to the Docker registry
.PHONY: docker-push
docker-push:
	@$(foreach TAG,$(DOCKER_PUSH_TAGS),docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);echo;)

# Load the project image from file
.PHONY: docker-load-image
docker-load-image:
	@cat $(DOCKER_IMAGE_DEPOT)/$(DOCKER_PROJECT)-$(DOCKER_NAME)-$(DOCKER_IMAGE_TAG).image | \
	gunzip | docker image load

# Save the project image to file
.PHONY: docker-save-image
docker-save-image:
	@docker image save $(foreach TAG,$(DOCKER_IMAGE_TAG) $(DOCKER_IMAGE_TAGS), $(DOCKER_IMAGE_NAME):$(TAG)) | \
	gzip > $(DOCKER_IMAGE_DEPOT)/$(DOCKER_PROJECT)-$(DOCKER_NAME)-$(DOCKER_IMAGE_TAG).image

### CIRCLE_CI ##################################################################

# Update the Dockerspec tag in the CircleCI configuration
.PHONY: ci-update-config
ci-update-config: docker-pull-testimage
	@TEST_IMAGE_DIGEST="$$(docker image inspect $(TEST_IMAGE) --format '{{index .RepoDigests 0}}')"; \
	 sed -i~ -E -e "s|-[[:space:]]*image:[[:space:]]*$(TEST_IMAGE_NAME)(@sha256)?:.*|- image: $${TEST_IMAGE_DIGEST}|" $(CIRCLECI_CONFIG_FILE); \
	 if diff $(CIRCLECI_CONFIG_FILE)~ $(CIRCLECI_CONFIG_FILE) > /dev/null; then \
		$(ECHO) "CircleCI configuration is up-to-date"; \
	 else \
		$(ECHO) "Updating CircleCI Docker executor image to $${TEST_IMAGE_DIGEST}"; \
	 fi
	@rm -f $(CIRCLECI_CONFIG_FILE)~

################################################################################
