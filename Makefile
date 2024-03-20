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

# --- Makefile variables -------------------------------------------------------
BASEDIR				:= $(shell pwd)
DEFAULT_CONFIG		:= $(BASEDIR)/inventory/group_vars/all.yml
ROLEDIR				:= $(shell realpath ~/src/ansible/roles/)
REPOS				:= $(shell find $(ROLEDIR) -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
PLAYDIR				:= $(BASEDIR)/playbooks
PLAYS				:= $(basename $(notdir $(wildcard $(PLAYDIR)/*.yml)))
# --- Makefile targets ---------------------------------------------------------

.PHONY: help install upgrade clean

# default target
help:
	@bin/help.sh

# --- prerequisites ------------------------------------------------------------

# check for requirements.txt
$(REQS):
	@echo "requirements.txt not found"
	@exit 1

# create the python virtual environment
$(VENV) upgrade: $(REQS)
	@bin/install-venv.sh $(VENV) $<

# --- targets for the python virtual environment -------------------------------

# install the python virtual environment
install: $(VENV)

# upgrade the python virtual environment

clean:
	@rm -rf $(VENV)

# --- targets for roles --------------------------------------------------------

.PHONY: config docs $(PLAYBOOKS) 

# --- configuration targets ----------------------------------------------------

define gitcap
	@cd $(ROLEDIR)/$(1) && git add .
	@if ! git diff --cached --quiet; then \
		codegpt commit && git push origin dev; \
		git checkout main && git merge dev && git push origin main && git checkout dev; \
	fi
endef

.PHONY: $(REPOS) quickshot pre-commit-autoupdate pre-commit-install

# run all configuration targets for specified role
$(REPOS): ansible-role-%:
	@echo "Running all for $*"
	@$(ANSIBLE_PLAYBOOK) $(PLAYDIR)/all.yml --limit=$*
	@$(call gitcap,$@)

# function to generate rules for single role targets
define generate_rules
.PHONY: $(1)/$(2)
$(1)/$(2):
	@echo "Running $(2) for $(1)"
	@$(ANSIBLE_PLAYBOOK) $(PLAYDIR)/$(2).yml --limit=$(subst ansible-role-,,$(1))
	@$(call gitcap,$(1))
endef

# generate rules for single role targets
$(foreach repo,$(REPOS),$(foreach play,$(PLAYS),$(eval $(call generate_rules,$(repo),$(play)))))

# stage, commit and push changes of $LIMIT
quickshot:
	@bin/quickshot.sh $(ROLEDIR) $(LIMIT)

# run pre-commit autoupdate for all roles
all/pre-commit-autoupdate:
	@bin/pre-commit.sh autoupdate $(ROLEDIR)

# install pre-commit hooks for all roles
all/pre-commit-install:
	@bin/pre-commit.sh install $(ROLEDIR)

# --- git targets --------------------------------------------------------------

.PHONY: me-commit me-prepare-release me-version me-publish

me-commit:
	@git add .
	@codegpt commit
	@git push origin dev

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
