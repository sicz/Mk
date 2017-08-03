################################################################################

# GitHub repository
# git config --get remote.origin.url
# - https://github.com/sicz/docker-baseimage.git
# - git@github.com:sicz/docker-baseimage.git
GITHUB_URL		?= $(shell git config --get remote.origin.url | sed -E -e "s|^git@github.com:|https://github.com/|" -e "s|\.git$$||")
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

# Project home directory
DOCKER_HOME_DIR		?= $(CURDIR)
DOCKER_VARIANT_DIR	?= $(DOCKER_HOME_DIR)

################################################################################

# Load make configuration
DOCKER_CONFIG_MK	?= docker.config.mk
ifneq ($(wildcard $(DOCKER_CONFIG_MK)),)
include $(DOCKER_CONFIG_MK)
endif

################################################################################

# Baseimage name
BASEIMAGE_IMAGE		?= $(BASEIMAGE_NAME):$(BASEIMAGE_TAG)

################################################################################

# Docker name
DOCKER_REGISTRY		?= docker.io
DOCKER_PROJECT		?= $(GITHUB_USER)
DOCKER_NAME		?= $(shell echo $(GITHUB_REPOSITORY) | sed -E -e "s|^docker-||")
DOCKER_TAG		?= $(BASEIMAGE_TAG)

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

# Show info messages
DOCKER_ENTRYPOINT_INFO	?= yes
ifdef DOCKER_ENTRYPOINT_INFO
DOCKER_RUN_OPTS		+= --env "DOCKER_ENTRYPOINT_INFO=$(DOCKER_ENTRYPOINT_INFO)"
endif

# Docker exec command
DOCKER_EXEC_CMD		?= /bin/true

# Docker shell options and command
DOCKER_SHELL_OPTS	+= --interactive --tty
DOCKER_SHELL_CMD	?= /bin/bash

# Running container id
DOCKER_CONTAINER_ID	:= .container_id
DOCKER_CONTAINER_NAME	:= $(shell cat $(DOCKER_CONTAINER_ID) 2> /dev/null || echo "$(DOCKER_IMAGE)_`openssl rand -hex 3`" | sed -E "s/[^[:alnum:]_]+/_/g")

################################################################################

# Docker test home directory
DOCKER_TEST_DIR		?= $(DOCKER_BUILD_DIR)

# Docker test image
DOCKER_TEST_NAME	?= sicz/dockerspec
DOCKER_TEST_TAG		?= latest
DOCKER_TEST_IMAGE	?= $(DOCKER_TEST_NAME):$(DOCKER_TEST_TAG)

# Docker test options, command and args
DOCKER_TEST_VARS	+= $(DOCKER_BUILD_VARS)
DOCKER_TEST_OPTS	+= --interactive \
			   --tty \
			   --name $${DOCKER_TEST_ID} \
			   -v $(abspath $(DOCKER_TEST_DIR))/.rspec:/.rspec \
			   -v $(abspath $(DOCKER_TEST_DIR))/spec:/spec \
			   -v /var/run/docker.sock:/var/run/docker.sock \
			   $(foreach DOCKER_TEST_VAR,$(DOCKER_TEST_VARS),-e "$(DOCKER_TEST_VAR)=$($(DOCKER_TEST_VAR))") \
			   -e DOCKER_TEST_CONTAINER_ID=$${DOCKER_CONTAINER_ID} \
			   -e DOCKER_TEST_CONTAINER_NAME=$${DOCKER_CONTAINER_ID} \
			   --rm
DOCKER_TEST_CMD		?= rspec
DOCKER_TEST_ARGS	?= --format $(DOCKER_RSPEC_FORMAT)

# Rspec output format
DOCKER_RSPEC_FORMAT	?= documentation

# CircleCI configuration file
CIRCLECI_CONFIG_FILE	?= $(DOCKER_HOME_DIR)/.circleci/config.yml

################################################################################

DOCKER_PUSH_TAGS	?= $(DOCKER_TAG) $(DOCKER_TAGS)

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

.PHONY: github-info

define GITHUB_INFO
GITHUB_URL:		$(GITHUB_URL)
GITHUB_USER:		$(GITHUB_USER)
GITHUB_REPOSITORY:	$(GITHUB_REPOSITORY)

BUILD_DATE:		$(BUILD_DATE)
VCS_REF:		$(VCS_REF)

endef
export GITHUB_INFO

github-info:
	@$(ECHO) "$${GITHUB_INFO}"

################################################################################

.PHONY: docker-all docker-info
.PHONY: docker-build docker-rebuild docker-deploy docker-destroy
.PHONY: docker-create docker-start docker-stop docker-exec docker-shell
.PHONY: docker-status docker-logs docker-logs-tail docker-test docker-clean
.PHONY: docker-pull docker-pull-baseimage docker-pull-testimage docker-push

define DOCKER_INFO
BASEIMAGE_NAME:		$(BASEIMAGE_NAME)
BASEIMAGE_TAG:		$(BASEIMAGE_TAG)

DOCKER_REGISTRY:	$(DOCKER_REGISTRY)
DOCKER_PROJECT:		$(DOCKER_PROJECT)
DOCKER_NAME:		$(DOCKER_NAME)
DOCKER_TAG:		$(DOCKER_TAG)
DOCKER_TAGS:		$(DOCKER_TAGS)
DOCKER_IMAGE:		$(DOCKER_IMAGE)

DOCKER_FILE:		$(DOCKER_FILE)

CURDIR:				   $(CURDIR)
DOCKER_HOME_DIR:	$(DOCKER_HOME_DIR)	=> $(abspath $(DOCKER_HOME_DIR))
DOCKER_BUILD_DIR:	$(DOCKER_BUILD_DIR)	=> $(abspath $(DOCKER_BUILD_DIR))
DOCKER_TEST_DIR:	$(DOCKER_TEST_DIR)	=> $(abspath $(DOCKER_TEST_DIR))

DOCKER_BUILD_VARS:	$(DOCKER_BUILD_VARS)
DOCKER_BUILD_OPTS:	$(DOCKER_BUILD_OPTS)

DOCKER_RUN_OPTS:	$(DOCKER_RUN_OPTS)
DOCKER_RUN_CMD:		$(DOCKER_RUN_CMD)

DOCKER_EXEC_OPTS:	$(DOCKER_EXEC_OPTS)
DOCKER_EXEC_CMD:	$(DOCKER_EXEC_CMD)

DOCKER_SHELL_OPTS:	$(DOCKER_SHELL_OPTS)
DOCKER_SHELL_CMD:	$(DOCKER_SHELL_CMD)

DOCKER_TEST_NAME:	$(DOCKER_TEST_NAME)
DOCKER_TEST_TAG:	$(DOCKER_TEST_TAG)
DOCKER_TEST_IMAGE:	$(DOCKER_TEST_IMAGE)
DOCKER_TEST_VARS:	$(DOCKER_TEST_VARS)
DOCKER_TEST_OPTS:	$(DOCKER_TEST_OPTS)
DOCKER_TEST_CMD:	$(DOCKER_TEST_CMD)
DOCKER_TEST_ARGS:	$(DOCKER_TEST_ARGS)

endef
export DOCKER_INFO

docker-info:
	@set -eo pipefail; \
	$(ECHO) "$${DOCKER_INFO}" | sed -E -e $$'s/ +-/\\\n\\\t\\\t\\\t-/g' -e $$'s/([A-Z]) ([A-Z])/\\1\\\n\\\t\\\t\\\t\\2/g'

docker-build:
	@set -eo pipefail; \
	cd $(DOCKER_BUILD_DIR); \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) .

docker-rebuild:
	@set -eo pipefail; \
	cd $(DOCKER_BUILD_DIR); \
	$(ECHO) "Build date: $(BUILD_DATE)"; \
	$(ECHO) "Git revision: $(VCS_REF)"; \
	docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) --no-cache .

docker-deploy:
	@set -eo pipefail; \
	$(MAKE) docker-destroy; \
	$(MAKE) docker-start

docker-destroy:
	@set -eo pipefail; \
	for DOCKER_CONTAINER_ID in $$(ls .container_* 2>/dev/null | tr '\n' ' '); do \
		$(MAKE) docker-rm DOCKER_CONTAINER_ID=$${DOCKER_CONTAINER_ID}; \
	done

docker-rm:
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		if [ -n "$$(docker container ps --all --quiet --filter name=^/$${DOCKER_CONTAINER_ID}$$)" ]; then \
			$(ECHO) -n "Destroying container: "; \
			docker container rm $(DOCKER_REMOVE_OPTS) -f $${DOCKER_CONTAINER_ID} > /dev/null; \
			$(ECHO) "$${DOCKER_CONTAINER_ID}"; \
		fi; \
	fi; \
	rm -f $(DOCKER_CONTAINER_ID); \


docker-create: $(DOCKER_CONTAINER_ID)
	@true

$(DOCKER_CONTAINER_ID):
	@set -eo pipefail; \
	$(ECHO) -n "Creating container: "; \
	echo $(DOCKER_CONTAINER_NAME) > $(DOCKER_CONTAINER_ID); \
	docker create $(DOCKER_RUN_OPTS) --name $(DOCKER_CONTAINER_NAME) $(DOCKER_IMAGE) $(DOCKER_RUN_CMD) > /dev/null; \
	cat $(DOCKER_CONTAINER_ID)

docker-start: docker-create
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -z "$${DOCKER_CONTAINER_ID}" ]; then \
		$(ECHO) "ERROR: Container name not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi; \
	if [ -z "$$(docker container ps --quiet --filter name=^/$${DOCKER_CONTAINER_ID}$$)" ]; then \
		$(ECHO) -n "Starting container: "; \
		docker start $(DOCKER_START_OPTS) $${DOCKER_CONTAINER_ID}; \
	fi

docker-stop:
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -z "$${DOCKER_CONTAINER_ID}" ]; then \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit; \
	fi; \
	if [ -n "$$(docker container ps --quiet --filter name=^/$${DOCKER_CONTAINER_ID}$$)" ]; then \
		$(ECHO) -n "Stopping container: "; \
		docker stop $(DOCKER_STOP_OPTS) $${DOCKER_CONTAINER_ID} > /dev/null; \
		$(ECHO) "$${DOCKER_CONTAINER_ID}"; \
	fi

docker-status:
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker container ps --all --filter name=^/$${DOCKER_CONTAINER_ID}; \
	fi

docker-logs:
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -z "$${DOCKER_CONTAINER_ID}" ]; then \
		$(ECHO) "ERROR: Container name not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi; \
	docker logs $(DOCKER_LOGS_OPTS) $${DOCKER_CONTAINER_ID}; \

docker-logs-tail:
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -z "$${DOCKER_CONTAINER_ID}" ]; then \
		$(ECHO) "ERROR: Container name not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi; \
	docker logs $(DOCKER_LOGS_OPTS) -f $${DOCKER_CONTAINER_ID}; \

docker-exec: docker-start
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -z "$${DOCKER_CONTAINER_ID}" ]; then \
		$(ECHO) "ERROR: Container name not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi; \
	docker exec $(DOCKER_EXEC_OPTS) $${DOCKER_CONTAINER_ID} $(DOCKER_EXEC_CMD); \

docker-shell: docker-start
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -z "$${DOCKER_CONTAINER_ID}" ]; then \
		$(ECHO) "ERROR: Container name not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi; \
	docker exec $(DOCKER_SHELL_OPTS) $${DOCKER_CONTAINER_ID} $(DOCKER_SHELL_CMD); \

docker-test: docker-start
	@set -eo pipefail; \
	touch $(DOCKER_CONTAINER_ID); \
	export DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -z "$${DOCKER_CONTAINER_ID}" ]; then \
		$(ECHO) "ERROR: Container name not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi; \
	cd $(DOCKER_TEST_DIR); \
	if [ -n "$(DOCKER_TEST_IMAGE)" ]; then \
		DOCKER_TEST_ID="$${DOCKER_CONTAINER_ID}_test"; \
		echo $${DOCKER_TEST_ID} > .container_test; \
		docker run $(DOCKER_TEST_OPTS) $(DOCKER_TEST_IMAGE) $(DOCKER_TEST_CMD) $(DOCKER_TEST_ARGS); \
		rm -f .container_test; \
	else \
		export $(foreach DOCKER_TEST_VAR,$(DOCKER_TEST_VARS),$(DOCKER_TEST_VAR)="$($(DOCKER_TEST_VAR))"); \
		export DOCKER_TEST_CONTAINER_ID=$${DOCKER_CONTAINER_ID}; \
		export DOCKER_TEST_CONTAINER_NAME=$${DOCKER_CONTAINER_ID}; \
		$(DOCKER_TEST_CMD) $(DOCKER_TEST_ARGS); \
	fi

docker-clean: docker-destroy
	@set -eo pipefail; \
	find $(DOCKER_HOME_DIR) -type f -name '*~' | xargs rm -f

docker-pull:
	@set -eo pipefail; \
	$(foreach TAG,$(DOCKER_PULL_TAGS),docker pull $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);echo;)

docker-pull-baseimage:
	@set -eo pipefail; \
	docker pull $(BASEIMAGE_IMAGE)

docker-pull-testimage:
	@set -eo pipefail; \
	docker pull $(DOCKER_TEST_IMAGE)

docker-push:
	@set -eo pipefail; \
	$(foreach TAG,$(DOCKER_PUSH_TAGS),docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);echo;)


################################################################################

docker-all:
	@set -eo pipefail; \
	for DOCKER_SUBDIR in . $(DOCKER_SUBDIRS); do \
		cd $(abspath $(DOCKER_HOME_DIR))/$${DOCKER_SUBDIR}; \
		if [ "$${DOCKER_SUBDIR}" = "." ]; then \
			DOCKER_SUBDIR="latest"; \
		fi; \
		$(ECHO); \
		$(ECHO); \
		$(ECHO) "===> $${DOCKER_SUBDIR}"; \
		$(ECHO); \
		$(ECHO); \
		$(MAKE) $(DOCKER_TARGET) DOCKER_VARIANT=$${DOCKER_SUBDIR}; \
	done

# DOCKER_ALL_TARGET:
# $1 - <TARGET>
define DOCKER_ALL_TARGET
.PHONY: $(1)-all
$(1)-all: ; @$(MAKE) docker-all DOCKER_TARGET=$(1)
endef
$(foreach DOCKER_TARGET,$(DOCKER_ALL_TARGETS),$(eval $(call DOCKER_ALL_TARGET,$(DOCKER_TARGET))))

################################################################################

.PHONY: ci-build-and-test ci-update-config

ci-build-and-test:
	@set -eo pipefail; \
	if [ "$(realpath $(CURDIR))" != "$(realpath $(DOCKER_VARIANT_DIR))" ]; then \
		if [ -n "$$(docker image ls -q $(DOCKER_IMAGE))" ]; then \
			if [ -n "$(DOCKER_TAGS)" ]; then \
				echo "Adding tag $(DOCKER_TAGS) to $(DOCKER_IMAGE)"; \
				for DOCKER_TAG in $(DOCKER_TAGS); do \
					docker image tag $(DOCKER_IMAGE) $(DOCKER_IMAGE_NAME):$${DOCKER_TAG}; \
				done; \
			fi; \
			exit; \
		fi; \
	fi; \
	$(MAKE) docker-pull-baseimage; \
	$(MAKE) build; \
	$(MAKE) test

ifneq ($(wildcard $(CIRCLECI_CONFIG_FILE)),)
ci-update-config: docker-pull-testimage
	@set -eo pipefail; \
	DOCKER_TEST_IMAGE_DIGEST="$(shell docker image inspect $(DOCKER_TEST_IMAGE) --format '{{index .RepoDigests 0}}')"; \
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
