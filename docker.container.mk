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
ifndef BASEIMAGE_NAME
$(error Unable to determine base image name. Define BASEIMAGE_NAME.)
endif
ifndef BASEIMAGE_TAG
$(error Unable to determine base image tag. Define BASEIMAGE_TAG.)
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
ifeq ($(shell uname),Darwin)
BUILD_DATE		?= $(shell date -u -r `git log -1 $(VCS_REF) --date=unix --format=%cd` "+%Y-%m-%dT%H:%M:%SZ")
else
BUILD_DATE		?= $(shell date -u -d @`git log -1 $(VCS_REF) --date=unix --format=%cd` "+%Y-%m-%dT%H:%M:%SZ")
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

# Baseimage name
BASEIMAGE_IMAGE		?= $(BASEIMAGE_NAME):$(BASEIMAGE_TAG)

################################################################################

# Docker Registry
DOCKER_REGISTRY		?= docker.io

# Docker image name
DOCKER_IMAGE_NAME	?= $(DOCKER_PROJECT)/$(DOCKER_NAME)
DOCKER_IMAGE		?= $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

################################################################################

# Dockerfile name
DOCKER_FILE		?= Dockerfile

################################################################################

# Docker build directory
DOCKER_BUILD_DIR	?= $(DOCKER_HOME_DIR)

# Build image with tags
DOCKER_BUILD_OPTS	+= -t $(DOCKER_IMAGE) \
			   $(foreach TAG,$(DOCKER_TAGS),-t $(DOCKER_IMAGE_NAME):$(TAG))


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
			   DOCKER_PROJECT_URL \
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

# Docker test home directory
DOCKER_TEST_DIR		?= $(DOCKER_BUILD_DIR)

# Docker test image
DOCKER_TEST_NAME	?= sicz/dockerspec
DOCKER_TEST_TAG		?= latest
DOCKER_TEST_IMAGE	?= $(DOCKER_TEST_NAME):$(DOCKER_TEST_TAG)

# Docker test options and command
DOCKER_TEST_VARS	+= $(DOCKER_BUILD_VARS)
DOCKER_TEST_OPTS	+= -it \
			   -v $(abspath $(DOCKER_TEST_DIR))/.rspec:/.rspec \
			   -v $(abspath $(DOCKER_TEST_DIR))/spec:/spec \
			   -v /var/run/docker.sock:/var/run/docker.sock \
			   $(foreach DOCKER_TEST_VAR,$(DOCKER_TEST_VARS),-e "$(DOCKER_TEST_VAR)=$($(DOCKER_TEST_VAR))") \
			   -e DOCKER_CONTAINER_ID=$${DOCKER_CONTAINER_ID} \
			   --rm
DOCKER_TEST_CMD		?= docker run $(DOCKER_TEST_OPTS) $(DOCKER_TEST_IMAGE) rspec

# Rspec output format
DOCKER_RSPEC_FORMAT	?= progress

# CircleCI configuration file
CIRCLECI_CONFIG_FILE	?= $(DOCKER_HOME_DIR)/.circleci/config.yml

################################################################################

# Useful commands
ECHO			= /bin/echo

################################################################################

.PHONY: docker-build docker-rebuild docker-deploy docker-destroy docker-run
.PHONY: docker-start docker-stop docker-status docker-logs docker-logs-tail
.PHONY: docker-exec docker-shell docker-test docker-clean
.PHONY: docker-pull docker-pull-baseimage docker-pull-testimage docker-pull-all
.PHONY: docker-push

docker-build:
	@cd $(DOCKER_BUILD_DIR); \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) .

docker-rebuild: docker-pull-baseimage
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
	export DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	export $(foreach DOCKER_TEST_VAR,$(DOCKER_TEST_VARS),$(DOCKER_TEST_VAR)="$($(DOCKER_TEST_VAR))"); \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		cd $(DOCKER_TEST_DIR); \
		$(DOCKER_TEST_CMD) --format $(DOCKER_RSPEC_FORMAT); \
	fi

docker-clean: docker-destroy
	@find $(DOCKER_HOME_DIR) -type f -name '*~' | xargs rm -f

docker-pull:
	@for DOCKER_TAG in $(DOCKER_TAG) $(DOCKER_TAGS); do \
		docker pull $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$${DOCKER_TAG}; \
	done

docker-pull-baseimage:
	@docker pull $(BASEIMAGE_IMAGE)

docker-pull-testimage:
	@docker pull $(DOCKER_TEST_IMAGE)

docker-pull-all:
	@for SUBDIR in . $(DOCKER_SUBDIR); do \
		cd $(abspath $(DOCKER_HOME_DIR))/$${SUBDIR}; \
		$(MAKE) docker-pull-baseimage docker-pull docker-pull-testimage; \
	done

docker-push:
	@docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE); \
	$(foreach TAG,$(DOCKER_TAGS),docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);)

$(DOCKER_CONTAINER_ID):
	@$(ECHO) -n "Deploying container: "; \
	docker run $(DOCKER_RUN_OPTS) -d $(DOCKER_IMAGE) $(DOCKER_RUN_CMD) > $(DOCKER_CONTAINER_ID); \
	cat $(DOCKER_CONTAINER_ID)

################################################################################

.PHONY: ci-update-config

ifneq ($(wildcard $(CIRCLECI_CONFIG_FILE)),)
ci-update-config: docker-pull-testimage
	@DOCKER_TEST_IMAGE_DIGEST="$(shell docker image inspect $(DOCKER_TEST_IMAGE) --format '{{index .RepoDigests 0}}')"; \
	sed -i~ -E -e "s|-[[:space:]]*image:[[:space:]]*$(DOCKER_TEST_NAME)(@sha256)?:.*|- image: $${DOCKER_TEST_IMAGE_DIGEST}|" $(CIRCLECI_CONFIG_FILE); \
	if diff $(CIRCLECI_CONFIG_FILE)~ $(CIRCLECI_CONFIG_FILE) > /dev/null; then \
		$(ECHO) "CircleCI configuration is up-to-date"; \
	else \
		$(ECHO) "Updating CircleCI Docker executor image to: $${DOCKER_TEST_IMAGE_DIGEST}"; \
	fi; \
	rm -f $(CIRCLECI_CONFIG_FILE)~
else
ci-update-config:
	@true
endif

################################################################################
