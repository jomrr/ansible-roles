# =============================================================================
# Makefile for Ansible roles repository
# =============================================================================
MAKEFLAGS	+= --no-builtin-rules
MAKEFLAGS	+= --warn-undefined-variables

SHELL		:= /bin/bash
.SHELLFLAGS	:= -euo pipefail -c

.DEFAULT_GOAL	:= help

# --- Paths -------------------------------------------------------------------
TEMPLATES_DIR	:= playbooks/templates
ROLES_DIR	:= ../roles

# --- Venv / tooling ----------------------------------------------------------
VENV		:= .ansible/venv
ANSIBLE		:= $(VENV)/bin/ansible
GALAXY		:= $(VENV)/bin/ansible-galaxy
PIP		:= $(VENV)/bin/pip

REQ_PYTHON	?= requirements.txt
REQ_GALAXY	?= requirements.yml

# --- Discovery ---------------------------------------------------------------
ROLES		:= $(notdir $(wildcard $(ROLES_DIR)/*))
TPLS		:= $(patsubst %.j2,%,$(shell find $(TEMPLATES_DIR) -type f -name '*.j2' -printf '%P\n'))

# All outputs for all roles
ROLE_OUTS := $(foreach r,$(ROLES),$(addprefix $(ROLES_DIR)/$(r)/,$(TPLS)))

# --- Help --------------------------------------------------------------------
.PHONY: help
help:
	@echo "Targets:"
	@echo "  make install                   - create venv + install python + galaxy reqs"
	@echo "  make render                    - render all templates for all roles (mtime-based)"
	@echo "  make ../roles/<role>/README.md - render one file for one role"
	@echo "  make list                      - show discovered roles"
	@echo "  make clean                     - remove venv"
	@echo ""
	@echo "Aggregates:"
	@echo "  make readmes metas molecules licenses pyprojects reqs hostvars"

.PHONY: list
list:
	@echo "ROLES=$(ROLES)"

# --- Venv / deps -------------------------------------------------------------
$(VENV):
	@mkdir -p $(dir $(VENV))
	@python3 -m venv $(VENV)

.PHONY: req-python req-galaxy install
req-python: $(REQ_PYTHON) | $(VENV)
	@$(PIP) install --upgrade pip
	@$(PIP) install -r $(REQ_PYTHON)

req-galaxy: $(REQ_GALAXY) | $(VENV)
	@$(GALAXY) install -fr $(REQ_GALAXY)

install: req-python req-galaxy
	@echo "Install complete."

# --- File-driven render rules (mtime-based) ----------------------------------
GROUP_VARS := $(wildcard inventory/group_vars/all/*.yml)

define declare_tpl_rule
$(ROLES_DIR)/$(1)/$(2): $(TEMPLATES_DIR)/$(2).j2 $(GROUP_VARS) inventory/host_vars/$(1).yml | $(VENV)
	@mkdir -p $$(dir $$@)
	@$(ANSIBLE) $(1) -m ansible.builtin.template -a "src=$$(abspath $$<) dest=$$(abspath $$@)"
endef

$(foreach r,$(ROLES),$(foreach t,$(TPLS),$(eval $(call declare_tpl_rule,$(r),$(t)))))

$(foreach r,$(ROLES),$(foreach t,$(TPLS), \
  $(eval .PHONY: roles/$(r)/$(t)) \
  $(eval roles/$(r)/$(t): $(ROLES_DIR)/$(r)/$(t)) \
))

# --- Aggregates --------------------------------------------------------------
.PHONY: render
render: $(ROLE_OUTS)
	@echo "Rendered all (mtime-based)."

READMES     := $(ROLES:%=$(ROLES_DIR)/%/README.md)
LICENSES    := $(ROLES:%=$(ROLES_DIR)/%/LICENSE)
PYPROJECTS  := $(ROLES:%=$(ROLES_DIR)/%/pyproject.toml)
HOSTVARS    := $(ROLES:%=$(ROLES_DIR)/%/host_vars.yml)

METAS       := $(foreach r,$(ROLES),$(ROLES_DIR)/$(r)/meta/main.yml $(ROLES_DIR)/$(r)/meta/requirements.yml)
MOLECULES   := $(foreach r,$(ROLES),$(ROLES_DIR)/$(r)/molecule/molecule.yml $(ROLES_DIR)/$(r)/molecule/playbook.yml)
REQS        := $(foreach r,$(ROLES),$(ROLES_DIR)/$(r)/requirements.yml $(ROLES_DIR)/$(r)/requirements.txt)

.PHONY: readmes licenses pyprojects hostvars metas molecules reqs
readmes:    $(READMES)
licenses:   $(LICENSES)
pyprojects: $(PYPROJECTS)
hostvars:   $(HOSTVARS)
metas:      $(METAS)
molecules:  $(MOLECULES)
reqs:       $(REQS)

# --- Pre-Commit --------------------------------------------------------------

# per role pre-commit targets
.PHONY: $(ROLES:%=precommit-role/install/%) \
        $(ROLES:%=precommit-role/run/%) \
        $(ROLES:%=precommit-role/autoupdate/%)

$(ROLES:%=precommit-role/install/%):
	@bin/dev precommit-role install $(notdir $@)

$(ROLES:%=precommit-role/run/%):
	@bin/dev precommit-role run $(notdir $@)

$(ROLES:%=precommit-role/autoupdate/%):
	@bin/dev precommit-role autoupdate $(notdir $@)

# aggregate pre-commit targets
.PHONY: precommit-roles/install precommit-roles/run precommit-roles/autoupdate
precommit-roles/install:    $(ROLES:%=precommit-role/install/%)
precommit-roles/run:        $(ROLES:%=precommit-role/run/%)
precommit-roles/autoupdate: $(ROLES:%=precommit-role/autoupdate/%)

# pre-commit targets for the ansible-roles repo itself
.PHONY: precommit/install precommit/run precommit/autoupdate
precommit/install:          ; @bin/dev precommit install
precommit/run:              ; @bin/dev precommit run
precommit/autoupdate:       ; @bin/dev precommit autoupdate

# --- Clean -------------------------------------------------------------------
.PHONY: clean
clean:
	@rm -rf $(VENV)
	@echo "Cleaned up $(VENV)."
