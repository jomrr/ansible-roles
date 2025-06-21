# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/readme.mk
# Makefile for generating LICENSE from templates

LICENSES	:= $(ROLES:%=roles/%/LICENSE)

.PHONY: licenses
licenses: $(LICENSES)

$(LICENSES): roles/%/LICENSE:

roles/%/LICENSE: $(TEMPLATES_DIR)/LICENSE.j2
	$(TEMPLATE) -a "src=$(abspath $<) dest=$(abspath $@)" $*
