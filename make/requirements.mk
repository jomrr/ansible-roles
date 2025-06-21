# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/readme.mk
# Makefile for generating requirements.yml from templates

REQUIREMENTS	:= $(ROLES:%=roles/%/requirements.yml)

.PHONY: requirements
requirements: $(REQUIREMENTS)

$(REQUIREMENTS): roles/%/requirements.yml:

roles/%/requirements.yml: $(TEMPLATES_DIR)/requirements.yml.j2
	$(TEMPLATE) -a "src=$(abspath $<) dest=$(abspath $@)" $*
