# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/readme.mk
# Makefile for generating pyproject.toml from templates

PYPROJECTS	:= $(ROLES:%=roles/%/pyproject.toml)

.PHONY: pyprojects
pyprojects: $(PYPROJECTS)

$(PYPROJECTS): roles/%/pyproject.toml:

roles/%/pyproject.toml: $(TEMPLATES_DIR)/pyproject.toml.j2
	$(TEMPLATE) -a "src=$(abspath $<) dest=$(abspath $@)" $*
