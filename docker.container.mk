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
DOCKER_TEST_OPTS	?= --interactive \
			   --tty \
			   --name $${DOCKER_TEST_ID} \
			   -v $(abspath $(DOCKER_TEST_DIR))/.rspec:/.rspec \
			   -v $(abspath $(DOCKER_TEST_DIR))/spec:/spec \
			   -v /var/run/docker.sock:/var/run/docker.sock \
			   $(foreach DOCKER_TEST_VAR,$(DOCKER_TEST_VARS),-e "$(DOCKER_TEST_VAR)=$($(DOCKER_TEST_VAR))") \
			   -e DOCKER_CONTAINER_ID=$${DOCKER_CONTAINER_ID} \
			   --rm
DOCKER_TEST_CMD		?= rspec
DOCKER_TEST_ARGS	?= --format $(DOCKER_RSPEC_FORMAT)

# Rspec output format
DOCKER_RSPEC_FORMAT	?= documentation

# CircleCI configuration file
CIRCLECI_CONFIG_FILE	?= $(DOCKER_HOME_DIR)/.circleci/config.yml

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

endef
export GITHUB_INFO

github-info:
	@$(ECHO) "$${GITHUB_INFO}"

################################################################################

.PHONY: docker-all docker-info docker-clean
.PHONY: docker-build docker-rebuild docker-deploy docker-destroy
.PHONY: docker-run docker-start docker-stop docker-exec docker-shell
.PHONY: docker-status docker-logs docker-logs-tail docker-test
.PHONY: docker-pull docker-pull-all docker-pull-baseimage docker-pull-testimage
.PHONY: docker-push

docker-all:
	@for DOCKER_SUBDIR in . $(DOCKER_SUBDIRS); do \
		cd $(abspath $(DOCKER_HOME_DIR))/$${DOCKER_SUBDIR}; \
		if [ "$${DOCKER_SUBDIR}" = "." ]; then \
			DOCKER_SUBDIR="latest"; \
		fi; \
		$(ECHO); \
		$(ECHO); \
		$(ECHO) "===> $${DOCKER_SUBDIR}"; \
		$(ECHO); \
		$(ECHO); \
		$(MAKE) $(TARGET) DOCKER_VARIANT=$${DOCKER_SUBDIR}; \
	done

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

CURDIR			$(CURDIR)
DOCKER_HOME_DIR:	$(abspath $(DOCKER_HOME_DIR))
DOCKER_BUILD_DIR:	$(abspath $(DOCKER_BUILD_DIR))
DOCKER_TEST_DIR:	$(abspath $(DOCKER_TEST_DIR))

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
	@$(ECHO) "$${DOCKER_INFO}" | sed -E -e $$'s/ +-/\\\n\\\t\\\t\\\t-/g' -e $$'s/([A-Z]) ([A-Z])/\\1\\\n\\\t\\\t\\\t\\2/g'

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
	@for DOCKER_CONTAINER_ID_FILE in $$(ls .container_* 2>/dev/null | tr '\n' ' '); do \
		DOCKER_CONTAINER_ID="$$(cat $${DOCKER_CONTAINER_ID_FILE})"; \
		if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
			if [ -n "$$(docker container ps --all --quiet --filter name=^/$${DOCKER_CONTAINER_ID}$$)" ]; then \
				$(ECHO) -n "Destroying container: "; \
				docker container rm $(DOCKER_REMOVE_OPTS) -f $${DOCKER_CONTAINER_ID} > /dev/null; \
				$(ECHO) "$${DOCKER_CONTAINER_ID}"; \
			fi; \
		fi; \
		rm -f $${DOCKER_CONTAINER_ID_FILE}; \
	done

docker-run: $(DOCKER_CONTAINER_ID)

$(DOCKER_CONTAINER_ID):
	@$(ECHO) -n "Deploying container: "; \
	echo $(DOCKER_CONTAINER_NAME) > $(DOCKER_CONTAINER_ID); \
	docker run $(DOCKER_RUN_OPTS) --name $(DOCKER_CONTAINER_NAME) -d $(DOCKER_IMAGE) $(DOCKER_RUN_CMD) > /dev/null; \
	cat $(DOCKER_CONTAINER_ID)

docker-start: docker-run
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		if [ -z "$$(docker container ps --quiet --filter name=^/$${DOCKER_CONTAINER_ID}$$)" ]; then \
			$(ECHO) -n "Starting container: "; \
			docker start $(DOCKER_START_OPTS) $${DOCKER_CONTAINER_ID} > /dev/null; \
			$(ECHO) "$${DOCKER_CONTAINER_ID}"; \
		fi; \
	else \
		$(ECHO) "ERROR: Container not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi

docker-stop:
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		if [ -n "$$(docker container ps --quiet --filter name=^/$${DOCKER_CONTAINER_ID}$$)" ]; then \
			$(ECHO) -n "Stopping container: "; \
			docker stop $(DOCKER_STOP_OPTS) $${DOCKER_CONTAINER_ID} > /dev/null; \
			$(ECHO) "$${DOCKER_CONTAINER_ID}"; \
		fi; \
	else \
		$(ECHO) "ERROR: Container not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi

docker-status:
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker container ps --all --filter name=^/$${DOCKER_CONTAINER_ID}; \
	fi

docker-logs:
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker logs $(DOCKER_LOGS_OPTS) $${DOCKER_CONTAINER_ID}; \
	else \
		$(ECHO) "ERROR: Container not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi

docker-logs-tail:
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker logs $(DOCKER_LOGS_OPTS) -f $${DOCKER_CONTAINER_ID}; \
	else \
		$(ECHO) "ERROR: Container not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi

docker-exec: docker-start
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker exec $(DOCKER_EXEC_OPTS) $${DOCKER_CONTAINER_ID} $(DOCKER_EXEC_CMD); \
	else \
		$$(ECHO) "ERROR: Container not found"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi

docker-shell: docker-start
	@touch $(DOCKER_CONTAINER_ID); \
	DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		docker exec $(DOCKER_SHELL_OPTS) $${DOCKER_CONTAINER_ID} $(DOCKER_SHELL_CMD); \
	else \
		$(ECHO) "ERROR: Container is not running"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi

docker-test: docker-start
	@touch $(DOCKER_CONTAINER_ID); \
	export DOCKER_CONTAINER_ID="$$(cat $(DOCKER_CONTAINER_ID))"; \
	if [ -n "$${DOCKER_CONTAINER_ID}" ]; then \
		cd $(DOCKER_TEST_DIR); \
		if [ -n "$(DOCKER_TEST_IMAGE)" ]; then \
			DOCKER_TEST_ID="$${DOCKER_CONTAINER_ID}_test"; \
			echo $${DOCKER_TEST_ID} > .container_test; \
			docker run $(DOCKER_TEST_OPTS) $(DOCKER_TEST_IMAGE) $(DOCKER_TEST_CMD) $(DOCKER_TEST_ARGS); \
			rm -f .container_test; \
		else \
			export $(foreach DOCKER_TEST_VAR,$(DOCKER_TEST_VARS),$(DOCKER_TEST_VAR)="$($(DOCKER_TEST_VAR))"); \
			$(DOCKER_TEST_CMD) $(DOCKER_TEST_ARGS); \
		fi; \
	else \
		$(ECHO) "ERROR: Container is not running"; \
		rm -f $(DOCKER_CONTAINER_ID); \
		exit 1; \
	fi

docker-clean: docker-destroy
	@find $(DOCKER_HOME_DIR) -type f -name '*~' | xargs rm -f

docker-pull:
	@for DOCKER_TAG in $(DOCKER_TAG) $(DOCKER_TAGS); do \
		docker pull $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$${DOCKER_TAG}; \
		$(ECHO); \
	done

docker-pull-all:
	@$(MAKE) docker-all TARGET=docker-pull

docker-pull-baseimage:
	@docker pull $(BASEIMAGE_IMAGE)

docker-pull-testimage:
	docker pull $(DOCKER_TEST_IMAGE); \

docker-push:
	@docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE); \
	$(foreach TAG,$(DOCKER_TAGS),docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(TAG);)

################################################################################

.PHONY: ci-rebuild-and-test ci-update-config

ci-rebuild-and-test:
	@if [ "$(realpath $(CURDIR))" != "$(realpath $(DOCKER_HOME_DIR))" ]; then \
		if [ -n "$$(docker image ls -q $(DOCKER_IMAGE))" ]; then \
			echo "Adding tag $(DOCKER_TAGS) to $(DOCKER_IMAGE)"; \
			for DOCKER_TAG in $(DOCKER_TAGS); do \
				docker image tag $(DOCKER_IMAGE) $(DOCKER_IMAGE_NAME):$${DOCKER_TAG}; \
			done; \
			exit; \
		fi; \
	fi; \
	$(MAKE) rebuild; \
	$(MAKE) test

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
