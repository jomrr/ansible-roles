# Makefile
# ansible-roles

SHELL				:= /bin/bash

# --- Variables for python virtual environment ---------------------------------
VENV				:= .venv
DEPS				:= collections/ansible_collections/jam82/dev
REQS				:= requirements.txt
PIP					:= $(VENV)/bin/pip
# --- Ansible variables --------------------------------------------------------
ANSIBLE				:= $(VENV)/bin/ansible
ANSIBLE_GALAXY		:= $(VENV)/bin/ansible-galaxy
ANSIBLE_INVENTORY	:= $(VENV)/bin/ansible-inventory
ANSIBLE_LINT		:= $(VENV)/bin/ansible-lint
ANSIBLE_PLAYBOOK	:= $(VENV)/bin/ansible-playbook
ANSIBLE_VAULT		:= $(VENV)/bin/ansible-vault
LIMIT				?= test
EXTRA_VARS			?=
SKIP_TAGS			?=
TAGS				?=

# --- Git variables ------------------------------------------------------------
FEATURE				?= feature/dummy
# --- Makefile variables -------------------------------------------------------
BASEDIR				:= $(shell pwd)
ROLEDIR				:= $(realpath ~/src/ansible/roles)
PLAYDIR				:= $(BASEDIR)/playbooks
PLAYBOOKS			:= $(basename $(notdir $(wildcard $(PLAYDIR)/*.yml)))
DEFAULT_CONFIG		:= $(BASEDIR)/inventory/group_vars/all.yml
# --- Makefile targets ---------------------------------------------------------

# default target
.PHONY: help
help:
	@echo "Usage: make <target> [LIMIT=<hostname or group>]"
	@echo ""
	@echo "Targets:"
	@echo "  help                    Show this help"
	@echo ""
	@echo "  # --- python virtual environment targets -------------------------"
	@echo ""
	@echo "  install                 Install the python virtual environment"
	@echo "  update/upgrade          Update the python virtual environment"
	@echo "  clean                   Remove the python virtual environment"
	@echo ""
	@echo "  # --- ansible targets --------------------------------------------"
	@echo ""
	@echo "  all                     Run playbooks/all.yml"
	@echo "  config                  Run meta, pyproject, pre-commit-config"
	@echo "  docs                    Run contributing, license, readme"
	@echo ""
	@echo "  contributing            Generate CONTRIBUTING.md"
	@echo "  license                 Generate LICENSE.md"
	@echo "  readme                  Generate README.md"
	@echo "  meta                    Generate meta/*.yml"
	@echo "  molecule                Generate molecule scenarios and playbooks"
	@echo "  pre-commit-config       Generate .pre-commit-config.yaml"
	@echo "  pyproject               Generate pyproject.toml"
	@echo "  remove                  Remove configured files"
	@echo ""
	@echo "  # --- git targets ------------------------------------------------"
	@echo ""
	@echo "  quickshot               Stage, commit and push changes of \$$LIMIT"
	@echo "  me-checkout-dev         Checkout the dev branch"
	@echo "  me-start-feature        Start a new feature branch"
	@echo "  me-merge-feature-to-dev Merge a feature branch to dev"
	@echo "  me-commit               Stage and commit changes to current branch"
	@echo "  me-prepare-release      Prepare a release and merge dev to main"
	@echo "  me-version              Run python-semantic-release version"
	@echo "  me-publish              Run python-semantic-release publish"

# --- prerequisites ------------------------------------------------------------

# check for requirements.txt
$(REQS):
	@echo "requirements.txt not found"
	@exit 1

# create the python virtual environment
$(VENV): $(REQS)
	@python3 -m venv $(VENV)
	@$(PIP) install --upgrade pip
	@$(PIP) install -r $(REQS)
	@$(ANSIBLE_GALAXY) collection install \
		git+https://github.com/jam82/ansible-collection-dev,main
	@pre-commit install --hook-type commit-msg
	@pre-commit install

# --- targets for the python virtual environment -------------------------------
.PHONY: install upgrade clean

# install the python virtual environment
install: $(VENV)

# upgrade the python virtual environment
upgrade: $(REQS)
	@$(PIP) install --upgrade -r $(REQS)
	@$(ANSIBLE_GALAXY) collection install \
		git+https://github.com/jam82/ansible-collection-dev,main
	@pre-commit install --hook-type commit-msg
	@pre-commit install
	@pre-commit autoupdate

clean:
	@rm -rf $(VENV)

# --- targets for ansible ------------------------------------------------------
.PHONY: $(PLAYBOOKS)

$(DEFAULT_CONFIG):
	@echo "default config $(DEFAULT_CONFIG) not found"
	@exit 1

$(ROLEDIR): $(DEFAULT_CONFIG)
	@echo "ansible roles directory $(ROLEDIR) not found"
	@exit 1

config: meta pyproject pre-commit-config

docs: contributing license readme

$(PLAYBOOKS): $(ROLEDIR)
	@$(ANSIBLE_PLAYBOOK) $(PLAYDIR)/$@.yml \
		$(if $(EXTRA_VARS),--extra-vars "$(EXTRA_VARS)") \
		--limit=$(LIMIT) \
		$(if $(SKIP_TAGS),--skip-tags $(SKIP_TAGS)) \
		$(if $(TAGS),--tags $(TAGS))

quickshot:
	@cd ~/src/ansible/roles/ansible-role-$(LIMIT) && \
		pre-commit install && \
		pre-commit install --hook-type commit-msg && \
		pre-commit autoupdate && \
		git add . && \
		git commit -m "build: update configuration" && \
		git push && \
		git checkout main && \
		git merge dev && \
		git push && \
		git checkout dev

# --- git targets --------------------------------------------------------------
.PHONY: \
	me-checkout-dev \
	me-commit \
	me-start-feature \
	me-merge-feature-to-dev \
	me-prepare-release \
	me-version \
	me-publish

# checkout the dev branch
me-checkout-dev:
	@git checkout dev

# commit changes to the current branch
me-commit:
	@git add .
	@git commit

# start a new feature branch
me-start-feature:
	@git checkout -b $(FEATURE) dev

# merge a feature branch to dev
me-merge-feature-to-dev:
	@git checkout dev
	@git merge $(FEATURE)
	@git branch -d $(FEATURE)

# prepare a release and merge dev to main
me-prepare-release:
	@git push origin dev
	@git checkout main
	@git merge dev
	@git push origin main
	@git checkout dev

# bump the version number and update the changelog
me-version:
	@git checkout main
	@semantic-release version
	@git checkout dev
	@git merge main

# create a new Git tag and build the distribution files
me-publish:
	@git checkout main
	@semantic-release publish
	@git push origin main --tags
	@git checkout dev
