# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/readme.mk
# Makefile for generating README.md from templates

READMES	:= $(ROLES:%=roles/%/README.md)

.PHONY: readmes
readmes: $(READMES)

$(READMES): roles/%/README.md:

roles/%/README.md: $(TEMPLATES_DIR)/README.md.j2
	$(TEMPLATE) -a "src=$(abspath $<) dest=$(abspath $@)" $*
