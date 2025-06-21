# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/pre-commit.mk
# Makefile for generating .pre-commit-config.yaml from templates

PRECOMMIT 			:= $(abspath $(VENV)/bin/pre-commit)
PRECOMMIT_CONFIGS	:= $(ROLES:%=roles/%/.pre-commit-config.yaml)

.PHONY: pre-commit-configs
pre-commit-configs: $(PRECOMMIT_CONFIGS)

$(PRECOMMIT_CONFIGS): roles/%/.pre-commit-config.yaml:

roles/%/.pre-commit-config.yaml: $(TEMPLATES_DIR)/.pre-commit-config.yaml.j2
	$(TEMPLATE) -a "src=$(abspath $<) dest=$(abspath $@)" $*

# Dynamische pre-commit-Aktionen für alle Rollen (Makro-Block, aber direkt im File)
define declare_precommit_targets
roles/$(1)/pre-commit-install: roles/$(1)/.pre-commit-config.yaml
	cd roles/$(1) && \
	    $(PRECOMMIT) install --hook-type pre-commit && \
	    $(PRECOMMIT) install --hook-type commit-msg

roles/$(1)/pre-commit-autoupdate: roles/$(1)/.pre-commit-config.yaml
	cd roles/$(1) && \
	    $(PRECOMMIT) autoupdate

roles/$(1)/pre-commit-run: roles/$(1)/pre-commit-autoupdate
	cd roles/$(1) && \
	    $(PRECOMMIT) run --all-files --hook-stage manual
endef

# Targets für alle Rollen generieren
$(foreach role,$(ROLES),$(eval $(call declare_precommit_targets,$(role))))

.PHONY: pre-commit-install pre-commit-autoupdate pre-commit-run
pre-commit-install: $(ROLES:%=roles/%/pre-commit-install)
pre-commit-autoupdate: $(ROLES:%=roles/%/pre-commit-autoupdate)
pre-commit-run: $(ROLES:%=roles/%/pre-commit-run)
