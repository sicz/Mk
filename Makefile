ECHO		= /bin/echo

.PHONY: create help

help:
	@$(ECHO) "Usage: make create NAME=docker-my-project [OVERRIDE=yes]"

create:
	@if [ -z "$(NAME)" ]; then \
		$(ECHO) "ERROR: Docker project NAME must be defined"; \
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
	cp -Rnpv docker-project ../$(NAME)
