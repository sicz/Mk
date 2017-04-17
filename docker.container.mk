ifndef DOCKER_PROJECT
$(error Unable to determine Docker project name. Define DOCKER_PROJECT.)
endif
ifndef DOCKER_NAME
$(error Unable to determine Docker image name. Define DOCKER_NAME.)
endif
ifndef DOCKER_TAG
$(error Unable to determine Docker image tag. Define DOCKER_TAG.)
endif

ifneq ($(wildcard ../Mk/docker.local.mk),"")
include ../Mk/docker.local.mk
endif

BASE_IMAGE_TAG		?= $(DOCKER_TAG)

DOCKER_IMAGE		?= $(DOCKER_PROJECT)/$(DOCKER_NAME):$(DOCKER_TAG)
CONTAINER_NAME		?= $(DOCKER_PROJECT)_$(DOCKER_NAME)

DOCKER_FILE		?= Dockerfile
DOCKER_FILE_TEMPLATE	?= $(DOCKER_FILE).tpl
DOCKER_FILE_SUB		+= BASE_IMAGE_TAG \
			   DOCKER_PROJECT \
			   DOCKER_NAME \
			   DOCKER_TAG \
			   DOCKER_IMAGE \
			   CONTAINER_NAME
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

ifdef CONTAINER_NAME
DOCKER_RUN_OPTS		+= --name $(CONTAINER_NAME)
endif

ifdef DOCKER_USER
DOCKER_RUN_OPTS		+= --user $(DOCKER_USER)
DOCKER_EXEC_OPTS	+= --user $(DOCKER_USER)
DOCKER_SHELL_OPTS	+= --user $(DOCKER_USER)
endif

DOCKER_EXEC_CMD		?= /bin/true

DOCKER_SHELL_OPTS	+= --interactive --tty
DOCKER_SHELL_CMD	?= /bin/bash

CONTAINER_ID		?= .container_id
CONTAINER_EXISTS	?= .container_exists

DOCKERFILE_REFRESHED_AT	?= .refreshed_at

ECHO			= /bin/echo

.PHONY: docker-build docker-rebuild docker-deploy docker-destroy docker-run
.PHONY: docker-start docker-stop docker-status docker-logs docker-logs-tail
.PHONY: docker-exec docker-shell docker-clean

docker-build: $(DOCKER_FILE)
	@docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) .

docker-rebuild: docker-clean $(DOCKER_FILE)
	@docker build $(DOCKER_BUILD_OPTS) -f $(DOCKER_FILE) --no-cache .

docker-deploy:
	@$(MAKE) docker-destroy
	@$(MAKE) docker-start

docker-destroy:
	@$(ECHO) -n > $(CONTAINER_EXISTS)
	@if [ -e "$(CONTAINER_ID)" ]; then \
		docker container ps --all --quiet --filter=id=`cat $(CONTAINER_ID)` > $(CONTAINER_EXISTS); \
	fi
	-@if [ -n "`cat $(CONTAINER_EXISTS)`" ]; then \
		$(ECHO) -n "Destroing container: "; \
		docker container rm $(DOCKER_REMOVE_OPTS) -f `cat $(CONTAINER_ID)`; \
	fi
	-@rm -f $(CONTAINER_ID) $(CONTAINER_EXISTS)

docker-run: $(CONTAINER_ID)

docker-start: docker-run
	@$(ECHO) -n > $(CONTAINER_EXISTS)
	@if [ -e "$(CONTAINER_ID)" ]; then \
		docker container ps --quiet --filter=id=`cat $(CONTAINER_ID)` > $(CONTAINER_EXISTS); \
	fi
	-@if [ -z "`cat $(CONTAINER_EXISTS)`" ]; then \
		$(ECHO) -n "Starting container: "; \
		docker start $(DOCKER_START_OPTS) `cat $(CONTAINER_ID)`; \
	fi
	-@rm -f $(CONTAINER_EXISTS)

docker-stop:
	@$(ECHO) -n > $(CONTAINER_EXISTS)
	@if [ -e "$(CONTAINER_ID)" ]; then \
		docker container ps --quiet --filter=id=`cat $(CONTAINER_ID)` > $(CONTAINER_EXISTS); \
	fi
	-@if [ -n "`cat $(CONTAINER_EXISTS)`" ]; then \
		$(ECHO) -n "Stopping container: "; \
		docker stop $(DOCKER_STOP_OPTS) `cat $(CONTAINER_ID)`; \
	fi
	-@rm -f $(CONTAINER_EXISTS)

docker-status:
	@if [ -e "$(CONTAINER_ID)" ]; then \
		docker container ps --all --filter=id=`cat $(CONTAINER_ID)`; \
	fi

docker-logs:
	-@if [ -e "$(CONTAINER_ID)" ]; then \
		docker logs $(DOCKER_LOGS_OPTS) `cat $(CONTAINER_ID)`; \
	fi

docker-logs-tail:
	-@if [ -e "$(CONTAINER_ID)" ]; then \
		docker logs $(DOCKER_LOGS_OPTS) -f `cat $(CONTAINER_ID)`; \
	fi

docker-exec: docker-start
	@docker exec $(DOCKER_EXEC_OPTS) `cat $(CONTAINER_ID)` $(DOCKER_EXEC_CMD)

docker-shell: docker-start
	@docker exec $(DOCKER_SHELL_OPTS) `cat $(CONTAINER_ID)` $(DOCKER_SHELL_CMD)

docker-clean:
	@rm -f $(DOCKER_FILE) $(REFRESHED_AT)

$(DOCKER_FILE): Makefile $(DOCKER_FILE_TEMPLATE) $(DOCKERFILE_DEPS) $(DOCKERFILE_REFRESHED_AT)
	@$(ECHO) "$(DOCKER_FILE) refreshed at $(shell cat $(DOCKERFILE_REFRESHED_AT))"; \
	cat $(DOCKER_FILE_TEMPLATE) | sed -E \
		$(foreach VAR,$(DOCKER_FILE_SUB),-e "s/%%$(VAR)%%/$(subst ",\",$(subst /,\/,$($(VAR))))/g") \
		-e "s/%%REFRESHED_AT%%/$(shell cat $(DOCKERFILE_REFRESHED_AT))/g" \
	> $(DOCKER_FILE)
# Fix Atom Shell Syntax Highliter: ")

$(DOCKERFILE_REFRESHED_AT):
	@date -u +"%Y-%m-%dT%H:%M:%SZ" > $(DOCKERFILE_REFRESHED_AT)

$(CONTAINER_ID):
	@$(ECHO) -n "Deploying container: "
	@docker run $(DOCKER_RUN_OPTS) -d $(DOCKER_IMAGE) $(DOCKER_RUN_CMD) > $(CONTAINER_ID)
	@cat $(CONTAINER_ID)
