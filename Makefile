### SHELL ######################################################################

# Replace Debian Almquist Shell with Bash
ifeq ($(realpath $(SHELL)),/bin/dash)
SHELL   		:= /bin/bash
endif

# Exit immediately if a command exits with a non-zero exit status
# TODO: .SHELLFLAGS does not exists on obsoleted macOS X-Code make
# .SHELLFLAGS		= -ec
SHELL			+= -e

### COMMANDS ###################################################################

ECHO			= /bin/echo

### MAKE_TARGETS ###############################################################

.PHONY: help
help:
	@$(ECHO) "Usage: make create NAME=docker-my-project [OVERWRITE=yes]"

.PHONY: create
create:
	@if [ -z "$(NAME)" ]; then \
		$(ECHO) "ERROR: Docker project NAME must be defined"; \
		$(ECHO); \
		$(MAKE) help; \
		$(ECHO); \
		exit 1; \
	fi
	@if [ -e ../$(NAME) -a "$(OVERWRITE)" != "yes" ]; then \
		$(ECHO) "ERROR: The directory ../$(NAME) exist"; \
		$(ECHO); \
		$(MAKE) help; \
		$(ECHO); \
		exit 1; \
	fi
	@mkdir -p ../$(NAME)
	cp -afv docker-sample-project ../$(NAME)

################################################################################
