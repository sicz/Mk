ECHO		= /bin/echo

.PHONY: create-docker-project help

help:
	@$(ECHO) "Usage: make create-docker-project NAME=docker-my-project [OVERRIDE=yes]"

create:
	@if [ -z "$(NAME)" ]; then \
		$(ECHO) "ERROR: Docker container NAME must be defined"; \
		$(ECHO); \
		$(MAKE) help; \
		$(ECHO); \
		exit 1; \
	fi
	@if [ -e ../$(NAME) -a "$(OVERRIDE)" != "yes" ]; then \
		$(ECHO) "ERROR: folder ../$(NAME) exists"; \
		$(ECHO); \
		$(MAKE) help; \
		$(ECHO); \
		exit 1; \
	fi
	@mkdir -p ../$(NAME); \
	cp -Rpv docker-container ../$(NAME)
