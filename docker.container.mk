################################################################################

# Required variables
ifndef DOCKER_PROJECT
$(error Unable to determine Docker project name. Define DOCKER_PROJECT.)
endif
ifndef DOCKER_NAME
$(error Unable to determine Docker image name. Define DOCKER_NAME.)
endif
ifndef DOCKER_TAG
$(error Unable to determine Docker image tag. Define DOCKER_TAG.)
endif

################################################################################

# GitHub repository
GITHUB_USER		?= $(DOCKER_PROJECT)
GITHUB_REPOSITORY	?= docker-$(DOCKER_NAME)
GITHUB_URL		?= https://github.org/$(GITHUB_USER)/$(GITHUB_REPOSITORY)

ifeq ($(shell git status --porcelain),)
# Last commit revision
VCS_REF			?= $(shell git rev-parse --short HEAD)
# Last commit timestamp
ifeq ($(shell date -d @0),Thu Jan  1 01:00:00 CET 1970)
BUILD_DATE		?= $(shell date -u -d @`git log $(VCS_REF) --date=unix --format=%cd` "+%Y-%m-%dT%H:%M:%SZ")
else ifeq ($(shell date -r 0),Thu Jan  1 01:00:00 CET 1970)
BUILD_DATE		?= $(shell date -u -r `git log $(VCS_REF) --date=unix --format=%cd` "+%Y-%m-%dT%H:%M:%SZ")
else
BUILD_DATE		?= $(shell git log $(VCS_REF) --date=unix --format=%cI)
endif
else
# Uncommited changes
VCS_REF			?= $(shell git rev-parse --short HEAD)-dev
# Build date contains only date so subsequent builds are cached
BUILD_DATE		?= $(shell date -u "+%Y-%m-%d")
endif

################################################################################

# Project home directory
DOCKER_HOME_DIR		?= $(CURDIR)

################################################################################

# Load make configuration
DOCKER_CONFIG_MK	?= docker.config.mk
ifneq ($(wildcard $(DOCKER_CONFIG_MK)),)
include $(DOCKER_CONFIG_MK)
endif

################################################################################

# Base image tag
BASEIMAGE_TAG		?= $(DOCKER_TAG)

################################################################################

# Docker image name
DOCKER_IMAGE_NAME	?= $(DOCKER_PROJECT)/$(DOCKER_NAME)
DOCKER_IMAGE		?= $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

################################################################################

# Dockerfile name
DOCKER_FILE		?= Dockerfile

################################################################################

# Docker build directory
DOCKER_BUILD_DIR	?= $(DOCKER_HOME_DIR)

# Build image with name and tag
ifdef DOCKER_IMAGE
DOCKER_BUILD_OPTS	+= -t $(DOCKER_IMAGE)
endif

# Use http proxy when building image
ifdef http_proxy
DOCKER_BUILD_OPTS	+= --build-arg http_proxy=$(http_proxy)
else ifdef HTTP_PROXY
DOCKER_BUILD_OPTS	+= --build-arg http_proxy=$(HTTP_PROXY)
endif

# Dockerfile build arguments
DOCKER_BUILD_OPTS	+= $(foreach DOCKER_BUILD_VAR,$(DOCKER_BUILD_VARS),--build-arg "$(DOCKER_BUILD_VAR)=$($(DOCKER_BUILD_VAR))")
DOCKER_BUILD_VARS	+= BASEIMAGE_NAME \
			   BASEIMAGE_TAG \
			   BUILD_DATE \
			   DOCKER_DESCRIPTION \
			   DOCKER_IMAGE \
			   DOCKER_IMAGE_NAME \
			   DOCKER_NAME \
			   DOCKER_PROJECT \
			   DOCKER_TAG \
			   GITHUB_REPOSITORY \
			   GITHUB_URL \
			   GITHUB_USER \
			   VCS_REF

################################################################################

# Run commands as user
#DOCKER_USER		?= root
ifdef DOCKER_USER
DOCKER_RUN_OPTS		+= --user $(DOCKER_USER)
DOCKER_EXEC_OPTS	+= --user $(DOCKER_USER)
DOCKER_SHELL_OPTS	+= --user $(DOCKER_USER)
endif

# Docker exec command
DOCKER_EXEC_CMD		?= /bin/true

# Docker shell options and command
DOCKER_SHELL_OPTS	+= --interactive --tty
DOCKER_SHELL_CMD	?= /bin/bash

# Running container id
DOCKER_CONTAINER_ID	?= .container_id

################################################################################

# Docker test image
DOCKER_TEST_PROJECT	?= $(DOCKER_PROJECT)
DOCKER_TEST_NAME	?= dockerspec
DOCKER_TEST_TAG		?= 3.6
DOCKER_TEST_IMAGE_NAME	?= $(DOCKER_TEST_PROJECT)/$(DOCKER_TEST_NAME)
DOCKER_TEST_IMAGE	?= $(DOCKER_TEST_IMAGE_NAME):$(DOCKER_TEST_TAG)

DOCKER_TEST_OPTS	+= \
			   -t \
			   $(foreach DOCKER_TEST_VAR,$(DOCKER_BUILD_VARS),--env "$(DOCKER_TEST_VAR)=$($(DOCKER_TEST_VAR))")

# Docker test home directory
DOCKER_TEST_DIR		?= $(DOCKER_BUILD_DIR)

# CircleCI configuration file
CIRCLECI_CONFIG_FILE	?= $(DOCKER_HOME_DIR)/.circleci/config.yml

################################################################################

# Useful commands
ECHO			= /bin/echo

################################################################################

.PHONY: docker-build docker-rebuild docker-deploy docker-destroy docker-run
.PHONY: docker-start docker-stop docker-status docker-logs docker-logs-tail
.PHONY: docker-exec docker-shell docker-test docker-clean

docker-build:
	@cd $(DOCKER_BUILD_DIR); \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) .

docker-rebuild:
	@cd $(DOCKER_BUILD_DIR); \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) --no-cache .

docker-deploy:
	@$(MAKE) docker-destroy
	@$(MAKE) docker-start

docker-destroy:
	@touch "$(DOCKER_CONTAINER_ID)"; \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		if [ -n "$$(docker container ps --all --quiet --filter=id=$${DOCKER_CONTAINER_ID})" ]; then \
			$(ECHO) -n "Destroing container: "; \
			docker container rm $(DOCKER_REMOVE_OPTS) -f $${DOCKER_CONTAINER_ID}; \
		fi; \
	fi; \
	rm -f "$(DOCKER_CONTAINER_ID)"

docker-run: $(DOCKER_CONTAINER_ID)

docker-start: docker-run
	@touch "$(DOCKER_CONTAINER_ID)"; \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		if [ -z "$$(docker container ps --quiet --filter=id=$${DOCKER_CONTAINER_ID})" ]; then \
			$(ECHO) -n "Starting container: "; \
			docker start $(DOCKER_START_OPTS) $${DOCKER_CONTAINER_ID}; \
		fi; \
	fi

docker-stop:
	@touch "$(DOCKER_CONTAINER_ID)"; \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		if [ -n "$$(docker container ps --quiet --filter=id=$${DOCKER_CONTAINER_ID})" ]; then \
			$(ECHO) -n "Stopping container: "; \
			docker stop $(DOCKER_STOP_OPTS) $${DOCKER_CONTAINER_ID}; \
		fi; \
	fi

docker-status:
	@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
		if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
			docker container ps --all --filter=id=$${DOCKER_CONTAINER_ID}; \
		fi; \
	fi

docker-logs:
	@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
		if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
			docker logs $(DOCKER_LOGS_OPTS) $${DOCKER_CONTAINER_ID}; \
		fi; \
	fi

docker-logs-tail:
	@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
		if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
			docker logs $(DOCKER_LOGS_OPTS) -f $${DOCKER_CONTAINER_ID}; \
		fi; \
	fi

docker-exec: docker-start
	@touch "$(DOCKER_CONTAINER_ID)"; \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker exec $(DOCKER_EXEC_OPTS) $${DOCKER_CONTAINER_ID} $(DOCKER_EXEC_CMD); \
	fi

docker-shell: docker-start
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker exec $(DOCKER_SHELL_OPTS) $${DOCKER_CONTAINER_ID} $(DOCKER_SHELL_CMD); \
	fi

docker-test: docker-start $(CIRCLECI_CONFIG_FILE)
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker run \
			$(DOCKER_TEST_OPTS) \
			-v $(abspath $(DOCKER_TEST_DIR))/.rspec:/.rspec \
			-v $(abspath $(DOCKER_TEST_DIR))/spec:/spec \
			-v /var/run/docker.sock:/var/run/docker.sock \
			-e DOCKER_CONTAINER_ID=$${DOCKER_CONTAINER_ID} \
			--name sicz_dockerspec_$${DOCKER_CONTAINER_ID} \
			--rm \
			$(DOCKER_TEST_IMAGE) $(DOCKER_TEST_CMD); \
	fi

docker-clean: docker-destroy
	@true

$(DOCKER_CONTAINER_ID):
	@$(ECHO) -n "Deploying container: "; \
	docker run $(DOCKER_RUN_OPTS) -d $(DOCKER_IMAGE) $(DOCKER_RUN_CMD) > $(DOCKER_CONTAINER_ID); \
	cat $(DOCKER_CONTAINER_ID)

ifneq ($(wildcard $(CIRCLECI_CONFIG_FILE)),)
.PHONY: $(CIRCLECI_CONFIG_FILE)
$(CIRCLECI_CONFIG_FILE):
	@$(ECHO) "Updating CircleCI Docker image to: $(DOCKER_TEST_IMAGE)"
	@sed -i'' -e "s|-[[:space:]]*image:[[:space:]]*$(DOCKER_TEST_IMAGE_NAME):.*|- image: $(DOCKER_TEST_IMAGE)|" $@
else
.PHONY: $(CIRCLECI_CONFIG_FILE)
$(CIRCLECI_CONFIG_FILE:)
	@true
endif
