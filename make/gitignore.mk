# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/gitignore.mk
# Makefile for generating GITIGNORE from templates

GITIGNORES	:= $(ROLES:%=roles/%/.gitignore)

.PHONY: gitignores
gitignores: $(GITIGNORES)

$(GITIGNORES): roles/%/.gitignore:

roles/%/.gitignore: $(TEMPLATES_DIR)/.gitignore.j2
	$(TEMPLATE) -a "src=$(abspath $<) dest=$(abspath $@)" $*
