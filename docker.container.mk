ifndef DOCKER_PROJECT
$(error Unable to determine Docker project name. Define DOCKER_PROJECT.)
endif
ifndef DOCKER_NAME
$(error Unable to determine Docker image name. Define DOCKER_NAME.)
endif
ifndef DOCKER_TAG
$(error Unable to determine Docker image tag. Define DOCKER_TAG.)
endif

ifneq ($(wildcard ../Mk/docker.config.mk),)
include ../Mk/docker.config.mk
DOCKERFILE_DEPS		+= ../Mk/docker.config.mk
endif

ifneq ($(wildcard ../Mk/docker.local.mk),)
include ../Mk/docker.local.mk
DOCKERFILE_DEPS		+= ../Mk/docker.local.mk
endif

ifneq ($(wildcard docker.local.mk),)
include docker.local.mk
DOCKERFILE_DEPS		+= docker.local.mk
endif

BASE_IMAGE_TAG		?= $(DOCKER_TAG)

DOCKERSPEC_VERSION	?= 17.03.1-ce

DOCKER_IMAGE		?= $(DOCKER_PROJECT)/$(DOCKER_NAME):$(DOCKER_TAG)
DOCKER_CONTAINER_NAME	?= $(shell echo "$(DOCKER_PROJECT)_$(DOCKER_NAME)" | tr "-" "_")

DOCKER_FILE		?= Dockerfile
DOCKER_FILE_TEMPLATE	?= $(DOCKER_FILE).tpl
DOCKER_FILE_SUB		+= BASE_IMAGE_TAG \
			   DOCKER_PROJECT \
			   DOCKER_NAME \
			   DOCKER_TAG \
			   DOCKER_IMAGE \
			   DOCKER_CONTAINER_NAME
			#  REFRESHED_AT is replaced separately

# DOCKER_USER		?= root

ifdef DOCKER_IMAGE
DOCKER_BUILD_OPTS	+= -t $(DOCKER_IMAGE)
endif

ifdef http_proxy
DOCKER_BUILD_OPTS	+= --build-arg http_proxy=$(http_proxy)
else ifdef HTTP_PROXY
DOCKER_BUILD_OPTS	+= --build-arg http_proxy=$(HTTP_PROXY)
endif

ifdef DOCKER_CONTAINER_NAME
DOCKER_RUN_OPTS		+= --name $(DOCKER_CONTAINER_NAME)
endif

ifdef DOCKER_USER
DOCKER_RUN_OPTS		+= --user $(DOCKER_USER)
DOCKER_EXEC_OPTS	+= --user $(DOCKER_USER)
DOCKER_SHELL_OPTS	+= --user $(DOCKER_USER)
endif

DOCKER_EXEC_CMD		?= /bin/true

DOCKER_SHELL_OPTS	+= --interactive --tty
DOCKER_SHELL_CMD	?= /bin/bash

DOCKER_CONTAINER_ID	?= .container_id
DOCKER_CONTAINER_EXISTS	?= .container_exists

DOCKERFILE_REFRESHED_AT	?= .refreshed_at

ECHO			= /bin/echo

.PHONY: docker-build docker-rebuild docker-deploy docker-destroy docker-run
.PHONY: docker-start docker-stop docker-status docker-logs docker-logs-tail
.PHONY: docker-exec docker-shell docker-refresh docker-test

docker-build: $(DOCKER_FILE)
	@docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) .

docker-rebuild: $(DOCKER_FILE)
	@docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) --no-cache .

docker-deploy:
	@$(MAKE) docker-destroy
	@$(MAKE) docker-start

docker-destroy:
	@$(ECHO) -n > $(DOCKER_CONTAINER_EXISTS)
	@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		docker container ps --all --quiet --filter=id=`cat $(DOCKER_CONTAINER_ID)` > $(DOCKER_CONTAINER_EXISTS); \
	fi
	-@if [ -n "`cat $(DOCKER_CONTAINER_EXISTS)`" ]; then \
		$(ECHO) -n "Destroing container: "; \
		docker container rm $(DOCKER_REMOVE_OPTS) -f `cat $(DOCKER_CONTAINER_ID)`; \
	fi
	-@rm -f $(DOCKER_CONTAINER_ID) $(DOCKER_CONTAINER_EXISTS)

docker-run: $(DOCKER_CONTAINER_ID)

docker-start: docker-run
	@$(ECHO) -n > $(DOCKER_CONTAINER_EXISTS)
	@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		docker container ps --quiet --filter=id=`cat $(DOCKER_CONTAINER_ID)` > $(DOCKER_CONTAINER_EXISTS); \
	fi
	-@if [ -z "`cat $(DOCKER_CONTAINER_EXISTS)`" ]; then \
		$(ECHO) -n "Starting container: "; \
		docker start $(DOCKER_START_OPTS) `cat $(DOCKER_CONTAINER_ID)`; \
	fi
	-@rm -f $(DOCKER_CONTAINER_EXISTS)

docker-stop:
	@$(ECHO) -n > $(DOCKER_CONTAINER_EXISTS)
	@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		docker container ps --quiet --filter=id=`cat $(DOCKER_CONTAINER_ID)` > $(DOCKER_CONTAINER_EXISTS); \
	fi
	-@if [ -n "`cat $(DOCKER_CONTAINER_EXISTS)`" ]; then \
		$(ECHO) -n "Stopping container: "; \
		docker stop $(DOCKER_STOP_OPTS) `cat $(DOCKER_CONTAINER_ID)`; \
	fi
	-@rm -f $(DOCKER_CONTAINER_EXISTS)

docker-status:
	@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		docker container ps --all --filter=id=`cat $(DOCKER_CONTAINER_ID)`; \
	fi

docker-logs:
	-@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		docker logs $(DOCKER_LOGS_OPTS) `cat $(DOCKER_CONTAINER_ID)`; \
	fi

docker-logs-tail:
	-@if [ -e "$(DOCKER_CONTAINER_ID)" ]; then \
		docker logs $(DOCKER_LOGS_OPTS) -f `cat $(DOCKER_CONTAINER_ID)`; \
	fi

docker-exec: docker-start
	@docker exec $(DOCKER_EXEC_OPTS) `cat $(DOCKER_CONTAINER_ID)` $(DOCKER_EXEC_CMD)

docker-shell: docker-start
	@docker exec $(DOCKER_SHELL_OPTS) `cat $(DOCKER_CONTAINER_ID)` $(DOCKER_SHELL_CMD)

docker-refresh:
	@rm -f $(DOCKER_FILE) $(DOCKERFILE_REFRESHED_AT)

docker-test: docker-start
	@docker run \
		$(DOCKER_TEST_OPTS) \
		-v $(CURDIR)/spec:/spec \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-e DOCKER_CONTAINER_ID=`cat $(DOCKER_CONTAINER_ID)` \
		--name sicz_dockerspec_$(DOCKER_CONTAINER_NAME) \
		--rm \
		sicz/dockerspec:$(DOCKERSPEC_VERSION) ${DOCKER_TEST_CMD}

$(DOCKER_FILE): Makefile $(DOCKER_FILE_TEMPLATE) $(DOCKERFILE_DEPS) $(DOCKERFILE_REFRESHED_AT)
	@$(ECHO) "$(DOCKER_FILE) refreshed at $(shell cat $(DOCKERFILE_REFRESHED_AT))"
	@cat $(DOCKER_FILE_TEMPLATE) | sed -E \
		$(foreach VAR,$(DOCKER_FILE_SUB),-e "s/%%$(VAR)%%/$(subst ",\",$(subst /,\/,$($(VAR))))/g") \
		-e "s/%%REFRESHED_AT%%/`cat $(DOCKERFILE_REFRESHED_AT)`/g" \
	> $(DOCKER_FILE)
# Fix Atom Shell Syntax Highliter: ")

$(DOCKERFILE_REFRESHED_AT):
	@date -u +"%Y-%m-%dT%H:%M:%SZ" > $(DOCKERFILE_REFRESHED_AT)

$(DOCKER_CONTAINER_ID):
	@$(ECHO) -n "Deploying container: "
	@docker run $(DOCKER_RUN_OPTS) -d $(DOCKER_IMAGE) $(DOCKER_RUN_CMD) > $(DOCKER_CONTAINER_ID)
	@cat $(DOCKER_CONTAINER_ID)
