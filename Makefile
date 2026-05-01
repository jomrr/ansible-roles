# =============================================================================
# Makefile for Ansible roles repository
# =============================================================================
MAKEFLAGS	+= --no-builtin-rules
MAKEFLAGS	+= --warn-undefined-variables

SHELL		:= /bin/bash
.SHELLFLAGS	:= -euo pipefail -c

.DEFAULT_GOAL	:= help

# --- Venv / tooling ----------------------------------------------------------
PYTHON		:= /usr/bin/python3
VENV		:= .ansible/venv
PIP		:= $(VENV)/bin/pip
PRC		:= $(VENV)/bin/pre-commit
PSR		:= $(VENV)/bin/semantic-release
LEG		:= $(VENV)/bin/leg

ANSIBLE_CFG	:= ansible.cfg
GALAXY		:= $(VENV)/bin/ansible-galaxy
PLAYBOOK	:= $(VENV)/bin/ansible-playbook

REQ_GALAXY	?= requirements.yml

export ANSIBLE_CONFIG := $(ANSIBLE_CFG)

# --- Discovery ---------------------------------------------------------------
ROLES		:= $(shell find -L roles -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
TPL_DIR		:= playbooks/templates

# --- Help --------------------------------------------------------------------
.PHONY: help
help:
	@echo "Targets:"
	@echo "  make help        show this help message (default)"
	@echo "  make install     install venv, Python and Galaxy requirements"
	@echo "  make upgrade     upgrade Python and Galaxy requirements"
	@echo "  make doctor      check tool versions"
	@echo "  make list        print table of discovered roles"
	@echo "  make clean       remove .ansible dirs"
	@echo "  make dist-clean  remove generated artifacts and .ansible dirs"
	@echo ""
	@echo "Single role artifacts:"
	@echo "  make roles/<role>/all"
	@echo "  make roles/<role>/.gitignore"
	@echo "  make roles/<role>/.pre-commit-config.yaml"
	@echo "  make roles/<role>/LICENSE"
	@echo "  make roles/<role>/README.md"
	@echo "  make roles/<role>/pyproject.toml"
	@echo "  make roles/<role>/requirements.yml"
	@echo "  make roles/<role>/meta"
	@echo "  make roles/<role>/molecule"
	@echo "  make roles/<role>/git/checkout-dev|checkout-main"
	@echo "  make roles/<role>/git/branch|fetch|pull|push|status|sync"
	@echo "  make roles/<role>/git/prepare-release"
	@echo "  make roles/<role>/git/commit MSG='...'"
	@echo "  make roles/<role>/git/commit-push MSG='...'"
	@echo "  make roles/<role>/pre-commit/install"
	@echo "  make roles/<role>/pre-commit/run"
	@echo "  make roles/<role>/pre-commit/autoupdate"
	@echo "  make roles/<role>/clean"
	@echo "  make roles/<role>/dist-clean"
	@echo ""
	@echo "All roles:"
	@echo "  make all"
	@echo "  make all/gitignores"
	@echo "  make all/pre-commits"
	@echo "  make all/licenses"
	@echo "  make all/readmes"
	@echo "  make all/pyprojects"
	@echo "  make all/requirements-python"
	@echo "  make all/requirements-galaxy"
	@echo "  make all/metas"
	@echo "  make all/molecules"
	@echo "  make all/git/status|branch|fetch|pull|push|sync"
	@echo "  make all/git/checkout-dev|checkout-main|prepare-release"
	@echo "  make all/git/commit MSG='...'"
	@echo "  make all/git/commit-push MSG='...'"
	@echo "  make all/pre-commit/install"
	@echo "  make all/pre-commit/run"
	@echo "  make all/pre-commit/autoupdate"
	@echo "  make all/clean"
	@echo "  make all/dist-clean"
	@echo ""
	@echo "Targets for this repository:"
	@echo "  make git/status|branch|fetch|pull|push|sync"
	@echo "  make git/checkout-dev|checkout-main|prepare-release"
	@echo "  make git/commit MSG='...'"
	@echo "  make git/commit-push MSG='...'"
	@echo "  make pre-commit/install"
	@echo "  make pre-commit/run"
	@echo "  make pre-commit/autoupdate"

.PHONY: doctor
doctor: | $(PLAYBOOK) $(GALAXY) $(PRC) $(PSR)
	@$(PLAYBOOK) --version
	@$(GALAXY) --version
	@$(PRC) --version
	@$(PSR) --version

.PHONY: list
list:
	@printf "%-24s %s\n" "ROLE" "PATH"
	@printf "%-24s %s\n" "----" "----"
	@for role in $(ROLES); do \
		printf "%-24s %s\n" "$$role" "roles/$$role"; \
	done

# --- Venv / deps -------------------------------------------------------------

$(PIP):
	@$(PYTHON) -m venv $(VENV)

# grouped target for python dependencies ~= one recipe builds multiple targets
$(GALAXY) $(PLAYBOOK) $(PRC) $(PSR) $(LEG) &: | $(PIP)
	@$(PIP) install --upgrade pip
	@$(PIP) install --upgrade --group tools

.PHONY: requirements-galaxy
requirements-galaxy: $(REQ_GALAXY) | $(GALAXY)
	@$(GALAXY) install -fr $(REQ_GALAXY)

.PHONY: install
install: requirements-galaxy
	@echo "Install complete."

.PHONY: upgrade
upgrade: requirements-galaxy | $(PIP)
	@$(PIP) install --upgrade pip
	@$(PIP) install --upgrade --group tools
	@echo "Upgrade complete."

# --- File-driven render rules (mtime-based) ----------------------------------
GROUP_VARS := $(wildcard inventory/group_vars/all/*.yml)
HOST_VARS  := inventory/host_vars

# .gitignore template
$(ROLES:%=roles/%/.gitignore): roles/%/.gitignore: \
	$(TPL_DIR)/.gitignore.j2 \
	$(GROUP_VARS) $(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/gitignore.yml

# .pre-commit-config.yaml template
$(ROLES:%=roles/%/.pre-commit-config.yaml): roles/%/.pre-commit-config.yaml: \
	$(TPL_DIR)/.pre-commit-config.yaml.j2 \
	$(GROUP_VARS) $(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/pre-commit.yml

# LICENSE template
$(ROLES:%=roles/%/LICENSE): roles/%/LICENSE: \
	$(TPL_DIR)/LICENSE.j2 \
	$(GROUP_VARS) $(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/license.yml

# README template
$(ROLES:%=roles/%/README.md): roles/%/README.md: \
	$(TPL_DIR)/README.md.j2 \
	$(GROUP_VARS) $(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/readme.yml

# pyproject.toml template
$(ROLES:%=roles/%/pyproject.toml): roles/%/pyproject.toml: \
	$(TPL_DIR)/pyproject.toml.j2 \
	$(GROUP_VARS) $(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/pyproject.yml

# requirements.yml template
$(ROLES:%=roles/%/requirements.yml): roles/%/requirements.yml: \
	$(TPL_DIR)/requirements.yml.j2 \
	$(GROUP_VARS) $(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/requirements-galaxy.yml

.PHONY: $(ROLES:%=roles/%/meta)
$(ROLES:%=roles/%/meta): roles/%/meta: \
	$(TPL_DIR)/meta/main.yml.j2 \
	$(TPL_DIR)/meta/argument_specs.yml.j2 \
	$(GROUP_VARS) \
	$(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/meta.yml

# molecule templates
$(ROLES:%=roles/%/molecule): roles/%/molecule: \
	$(TPL_DIR)/molecule/molecule.yml.j2 \
	$(TPL_DIR)/molecule/playbook.yml.j2 \
	$(GROUP_VARS) $(HOST_VARS)/%.yml | $(PLAYBOOK)
	@$(PLAYBOOK) --limit "$*" playbooks/molecule.yml

# per role pre-commit targets
.PHONY: $(ROLES:%=roles/%/pre-commit/install)
$(ROLES:%=roles/%/pre-commit/install): roles/%/pre-commit/install:
	@bin/pre-commit role install "$*"

.PHONY: $(ROLES:%=roles/%/pre-commit/run)
$(ROLES:%=roles/%/pre-commit/run): roles/%/pre-commit/run:
	@bin/pre-commit role run "$*"

.PHONY: $(ROLES:%=roles/%/pre-commit/autoupdate)
$(ROLES:%=roles/%/pre-commit/autoupdate): roles/%/pre-commit/autoupdate:
	@bin/pre-commit role autoupdate "$*"

# role-level target to build all generated artifacts for a role
.PHONY: $(ROLES:%=roles/%/all)
$(ROLES:%=roles/%/all): roles/%/all: \
	roles/%/.gitignore \
	roles/%/.pre-commit-config.yaml \
	roles/%/LICENSE \
	roles/%/README.md \
	roles/%/pyproject.toml \
	roles/%/requirements.yml \
	roles/%/meta \
	roles/%/molecule

# git: role-level git targets
.PHONY: $(ROLES:%=roles/%/git/branch)
$(ROLES:%=roles/%/git/branch): roles/%/git/branch:
	@bin/git role "$*" branch

.PHONY: $(ROLES:%=roles/%/git/checkout-dev)
$(ROLES:%=roles/%/git/checkout-dev): roles/%/git/checkout-dev:
	@bin/git role "$*" checkout-dev

.PHONY: $(ROLES:%=roles/%/git/checkout-main)
$(ROLES:%=roles/%/git/checkout-main): roles/%/git/checkout-main:
	@bin/git role "$*" checkout-main

.PHONY: $(ROLES:%=roles/%/git/fetch)
$(ROLES:%=roles/%/git/fetch): roles/%/git/fetch:
	@bin/git role "$*" fetch

.PHONY: $(ROLES:%=roles/%/git/pull)
$(ROLES:%=roles/%/git/pull): roles/%/git/pull:
	@bin/git role "$*" pull

.PHONY: $(ROLES:%=roles/%/git/push)
$(ROLES:%=roles/%/git/push): roles/%/git/push:
	@bin/git role "$*" push

.PHONY: $(ROLES:%=roles/%/git/status)
$(ROLES:%=roles/%/git/status): roles/%/git/status:
	@bin/git role "$*" status

.PHONY: $(ROLES:%=roles/%/git/prepare-release)
$(ROLES:%=roles/%/git/prepare-release): roles/%/git/prepare-release:
	@bin/git role "$*" prepare-release

.PHONY: $(ROLES:%=roles/%/git/commit)
$(ROLES:%=roles/%/git/commit): roles/%/git/commit:
	@bin/git role "$*" commit "$(MSG)"

.PHONY: $(ROLES:%=roles/%/git/commit-push)
$(ROLES:%=roles/%/git/commit-push): roles/%/git/commit-push: roles/%/git/commit roles/%/git/push

.PHONY: $(ROLES:%=roles/%/git/sync)
$(ROLES:%=roles/%/git/sync): roles/%/git/sync: roles/%/git/fetch roles/%/git/pull
	@bin/git role "$*" status

# leg: role level targets
.PHONY: $(ROLES:%=roles/%/repo/plan)
$(ROLES:%=roles/%/repo/plan): roles/%/repo/plan: | $(LEG)
	@$(LEG) role repo plan "$*"

.PHONY: $(ROLES:%=roles/%/repo/status)
$(ROLES:%=roles/%/repo/status): roles/%/repo/status: | $(LEG)
	@$(LEG) role repo status "$*"

.PHONY: $(ROLES:%=roles/%/repo/ensure)
$(ROLES:%=roles/%/repo/ensure): roles/%/repo/ensure: | $(LEG)
	@$(LEG) role repo ensure "$*"

.PHONY: $(ROLES:%=roles/%/repo/clone)
$(ROLES:%=roles/%/repo/clone): roles/%/repo/clone: | $(LEG)
	@$(LEG) role repo clone "$*"

.PHONY: $(ROLES:%=roles/%/repo/remotes)
$(ROLES:%=roles/%/repo/remotes): roles/%/repo/remotes: | $(LEG)
	@$(LEG) role repo remotes "$*"

.PHONY: $(ROLES:%=roles/%/repo/sync)
$(ROLES:%=roles/%/repo/sync): roles/%/repo/sync: | $(LEG)
	@$(LEG) role repo sync "$*"

.PHONY: $(ROLES:%=roles/%/release/status)
$(ROLES:%=roles/%/release/status): roles/%/release/status: | $(LEG)
	@$(LEG) role release status "$*"

.PHONY: $(ROLES:%=roles/%/release/prepare)
$(ROLES:%=roles/%/release/prepare): roles/%/release/prepare: | $(LEG)
	@$(LEG) role release prepare "$*"

.PHONY: $(ROLES:%=roles/%/release/version)
$(ROLES:%=roles/%/release/version): roles/%/release/version: | $(LEG)
	@$(LEG) role release version "$*"

.PHONY: $(ROLES:%=roles/%/release/publish)
$(ROLES:%=roles/%/release/publish): roles/%/release/publish: | $(LEG)
	@$(LEG) role release publish "$*"

.PHONY: $(ROLES:%=roles/%/release/run)
$(ROLES:%=roles/%/release/run): roles/%/release/run: | $(LEG)
	@$(LEG) role release "$*"

.PHONY: $(ROLES:%=roles/%/archive)
$(ROLES:%=roles/%/archive): roles/%/archive: | $(LEG)
	@$(LEG) role archive "$*"

# clean: remove tool artifacts and caches for a role
.PHONY: $(ROLES:%=roles/%/clean)
$(ROLES:%=roles/%/clean): roles/%/clean:
	@rm -rf roles/$*/.ansible
	@echo "Cleaned up role '$*'."

# dist-clean: remove generated artifacts for a role
.PHONY: $(ROLES:%=roles/%/dist-clean)
$(ROLES:%=roles/%/dist-clean): roles/%/dist-clean: roles/%/clean
	@rm -f roles/$*/.gitignore
	@rm -f roles/$*/.pre-commit-config.yaml
	@rm -f roles/$*/LICENSE
	@rm -f roles/$*/README.md
	@rm -f roles/$*/pyproject.toml
	@rm -f roles/$*/requirements.yml
	@rm -rf roles/$*/meta
	@rm -rf roles/$*/molecule
	@echo "Removed build artifacts for role '$*'."

# --- Aggregates --------------------------------------------------------------
.PHONY: all
all: \
	all/gitignores \
	all/licenses \
	all/metas \
	all/molecules \
	all/readmes \
	all/pre-commits \
	all/pyprojects \
	all/requirements-galaxy \
	all/requirements-python

.PHONY: all/gitignores
all/gitignores: $(ROLES:%=roles/%/.gitignore)

.PHONY: all/licenses
all/licenses: $(ROLES:%=roles/%/LICENSE)

.PHONY: all/metas
all/metas: $(ROLES:%=roles/%/meta)

.PHONY: all/molecules
all/molecules: $(ROLES:%=roles/%/molecule)

.PHONY: all/pre-commits
all/pre-commits: $(ROLES:%=roles/%/.pre-commit-config.yaml)

.PHONY: all/pyprojects
all/pyprojects: $(ROLES:%=roles/%/pyproject.toml)

.PHONY: all/readmes
all/readmes: $(ROLES:%=roles/%/README.md)

.PHONY: all/requirements-galaxy
all/requirements-galaxy: $(ROLES:%=roles/%/requirements.yml)

# aggregate pre-commit targets
.PHONY: all/pre-commit/install
all/pre-commit/install: $(ROLES:%=roles/%/pre-commit/install)

.PHONY: all/pre-commit/run
all/pre-commit/run: $(ROLES:%=roles/%/pre-commit/run)

.PHONY: all/pre-commit/autoupdate
all/pre-commit/autoupdate: $(ROLES:%=roles/%/pre-commit/autoupdate)

.PHONY: all/git/branch
all/git/branch: $(ROLES:%=roles/%/git/branch)

.PHONY: all/git/checkout-dev
all/git/checkout-dev: $(ROLES:%=roles/%/git/checkout-dev)

.PHONY: all/git/checkout-main
all/git/checkout-main: $(ROLES:%=roles/%/git/checkout-main)

.PHONY: all/git/fetch
all/git/fetch: $(ROLES:%=roles/%/git/fetch)

.PHONY: all/git/pull
all/git/pull: $(ROLES:%=roles/%/git/pull)

.PHONY: all/git/push
all/git/push: $(ROLES:%=roles/%/git/push)

.PHONY: all/git/status
all/git/status: $(ROLES:%=roles/%/git/status)

.PHONY: all/git/prepare-release
all/git/prepare-release: $(ROLES:%=roles/%/git/prepare-release)

.PHONY: all/git/commit
all/git/commit: $(ROLES:%=roles/%/git/commit)

.PHONY: all/git/commit-push
all/git/commit-push: $(ROLES:%=roles/%/git/commit-push)

.PHONY: all/git/sync
all/git/sync: $(ROLES:%=roles/%/git/sync)

.PHONY: all/repo/plan
all/repo/plan: $(ROLES:%=roles/%/repo/plan)

.PHONY: all/repo/status
all/repo/status: $(ROLES:%=roles/%/repo/status)

.PHONY: all/repo/remotes
all/repo/remotes: $(ROLES:%=roles/%/repo/remotes)

.PHONY: all/release/status
all/release/status: $(ROLES:%=roles/%/release/status)

.PHONY: all/clean
all/clean: $(ROLES:%=roles/%/clean)

.PHONY: all/dist-clean
all/dist-clean: $(ROLES:%=roles/%/dist-clean)

# --- Repo Targets ------------------------------------------------------------

# git targets for the ansible-roles repo itself
.PHONY: git/branch git/checkout-dev git/checkout-main git/fetch git/pull git/push git/status git/prepare-release
git/branch git/checkout-dev git/checkout-main git/fetch git/pull git/push git/status git/prepare-release: git/%:
	@bin/git repo $*

.PHONY: git/commit
git/commit:
	@bin/git repo commit "$(MSG)"

.PHONY: git/commit-push
git/commit-push: git/commit git/push

.PHONY: git/sync
git/sync: git/fetch git/pull
	@bin/git repo status

# pre-commit targets for the ansible-roles repo itself
.PHONY: pre-commit/install
pre-commit/install:
	@bin/pre-commit repo install
.PHONY: pre-commit/run
pre-commit/run:
	@bin/pre-commit repo run
.PHONY: pre-commit/autoupdate
pre-commit/autoupdate:
	@bin/pre-commit repo autoupdate

# --- Clean -------------------------------------------------------------------
.PHONY: clean
clean: all/clean
	@rm -rf $(CURDIR)/.ansible
	@echo "Cleaned up '$(CURDIR)/.ansible'."

.PHONY: dist-clean
dist-clean: all/dist-clean
	@rm -rf $(CURDIR)/.ansible
	@echo "Cleaned up generated artifacts and '$(CURDIR)/.ansible'."
