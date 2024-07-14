# Makefile
# ansible-roles

SHELL				:= /bin/bash

# --- Requirements and virtual env ---------------------------------------------
REQ_DNF				:= findutils git gh pipx
REQ_PYTHON			:= requirements.txt
REQ_GALAXY			:= requirements.yml
VENV				:= $(HOME)/.local/share/pipx/venvs/ansible

# --- Github variables ---------------------------------------------------------
GH_USER				?= jomrr
GH_CPFX				?= ansible-collection-
GH_RPFX				?= ansible-role-

GH_CMD				:= gh repo list $(GH_USER)
GH_JSON				:= $(GH_CMD) --limit 1000 --no-archived --source --json name

SELECT_COL			:= select(.name | startswith("$(GH_CPFX)")) | .name
SELECT_ROL			:= select(.name | startswith("$(GH_RPFX)")) | .name
SUB_COL				:= sub("^$(GH_CPFX)"; "") | .name
SUB_ROL				:= sub("^$(GH_RPFX)"; "") | .name

GH_COLLECTIONS		:= $(GH_JSON) --jq '.[] | $(SELECT_COL) |= $(SUB_COL)'
GH_ROLES			:= $(GH_JSON) --jq '.[] | $(SELECT_ROL) |= $(SUB_ROL)'

# --- Cache variables ----------------------------------------------------------
CACHE_DIR			:= cache

CACHE_GH_COLLECTIONS:= $(CACHE_DIR)/collections.github
CACHE_GH_ROLES		:= $(CACHE_DIR)/roles.github

# --- Ansible variables --------------------------------------------------------
ANSIBLE 			:= ansible
ANSIBLE_I			:= $(ANSIBLE) -i inventory/
ANSIBLE_PLAYBOOK	:= ansible-playbook -i inventory/
ANSIBLE_TPL_DIR		:= playbooks/templates
AM_TEMPLATE			:= $(ANSIBLE_I) -m template
ROLE_SKELETON		:= $(HOME)/src/ansible/skeleton-ansible-role

# --- Makefile variables -------------------------------------------------------
DIR_CWD				:= $(shell pwd)
CFG_DEFAULT			:= $(DIR_CWD)/inventory/group_vars/all.yml

DIR_COLLECTIONS		:= $(HOME)/src/ansible/collections/$(GH_USER)
DIR_ROLES			:= $(HOME)/src/ansible/roles

COLLECTIONS			:= $(shell cat $(CACHE_GH_COLLECTIONS))
ROLES				:= $(shell cat $(CACHE_GH_ROLES))

DIR_LIST_COLLECTIONS:= $(addprefix $(DIR_COLLECTIONS)/,$(COLLECTIONS))
DIR_LIST_ROLES	 	:= $(addprefix $(DIR_ROLES)/,$(ROLES))
COMBINED_REPO_LIST	:= $(DIR_LIST_COLLECTIONS) $(DIR_LIST_ROLES)

REMOVE 				:= .ansible-lint.yml .github .yamllint.yml requirements.txt
REMOVE				+= CONTRIBUTING.md

.DEFAULT_GOAL		:= help

# --- Functions ----------------------------------------------------------------

# cname, get the role or collection name from a path
define cname
	$(firstword $(subst /, ,$(subst $1,,$2)))
endef

.PRECIOUS: \
	$(DIR_LIST_COLLECTIONS) \
	$(DIR_LIST_ROLES) \
	$(GIT_DIR_COLLECTIONS) \
	$(GIT_DIR_ROLES) \
	$(META_PATHS) \
	$(MMAIN_PATHS) \
	$(MREQS_PATHS) \
	$(PYPROJECT_PATHS) \
	$(REQ_GALAXY) \
	$(REQ_PYTHON) \
	$(REQUIREMENTS_PATHS) \
	$(VENV)

# --- Internal targets ---------------------------------------------------------

# default target
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo "make -n [target] to dry-run"
	@echo "make -j [n] [target] to run [n] jobs in parallel"
	@echo "make -B [target] to force update"
	@echo
	@echo "Targets:"
	@echo "  help               Show this help"
	@echo "  install            Install ansible and tools"
	@echo "  upgrade            Upgrade ansible and tools"
	@echo "  cacheclean         Empty the cache"
	@echo "  clean              Delete the virtual environment"
	@echo "  unpip              Remove all pip user packages"
	@echo "  new-role           Create a new role skeleton"
	@echo "  collections/clone  Clone all collections from github"
	@echo "  collections/update Update all collections from github"
	@echo "  collections/dev    Checkout dev branch for all collections"
	@echo "  roles/clone        Clone all roles from github"
	@echo "  roles/update       Update all roles from github"
	@echo "  pyproject          Create or update all pyproject.toml files"
	@echo "  requirements       Create or update all requirements.yml files"
	@echo "  remove             Remove all files defined in REMOVE"
	@echo "  LICENSE            Create or update all LICENSE files"
	@echo "  meta               Create or update all meta directories"
	@echo "  meta/main.yml      Create or update all meta/main.yml files"
	@echo "  meta/requirements.yml Generate all meta/requirements.yml files"
	@echo "  molecule           Create molecule/ for all roles"
	@echo "  pre-commit-config  Create or update all pre-commit-config.yaml files"
	@echo "  README             Create or update all README.md files"
	@echo "  me-pc-install      Install pre-commit hooks"
	@echo "  me-pc-autoupdate   Update pre-commit hooks"
	@echo "  me-pc-run          Run pre-commit checks"
	@echo "  me-commit          Commit changes to dev branch and push to origin"
	@echo "  me-prepare-release Prepare a release and merge dev to main"
	@echo "  me-version         Bump the version number and update the changelog"
	@echo "  me-publish         Create a new git tag, build and publish release"

# check for requirements.txt
$(REQ_PYTHON):
	@echo "requirements.txt not found"
	@exit 1

# check for requirements.yml
$(REQ_GALAXY):
	@echo "requirements.yml not found"
	@exit 1

# install dnf packages
.PHONY: .req-dnf
.req-dnf:
	@sudo dnf install -qy $(REQ_DNF)

# install ansible with pipx
.PHONY: .req-pipx-ansible
.req-pipx-ansible: .req-dnf
	@pipx -q install ansible

# install tools to ansible virtual environment
.PHONY: .req-pipx-inject
.req-pipx-inject: $(REQ_PYTHON) .req-pipx-ansible
	@pipx -q inject --include-deps -r $< ansible

# ensure ansible and tools are in PATH
.PHONY: .req-pipx
.req-pipx: .req-pipx-inject
	@pipx -q ensurepath

# configure gh to use ssh
.PHONY: --config-gh
--config-gh: .req-dnf
	@grep "col: ssh" $(HOME)/.config/gh/config.yml &>/dev/null || \
		gh config set git_protocol ssh

# check and create python virtual environment
$(VENV): .req-pipx

# create cache directory
$(CACHE_DIR):
	@mkdir -p cache

# get all collections from github
$(CACHE_GH_COLLECTIONS): | $(CACHE_DIR)
	@echo "Updating collections cache from github.com"
	@$(GH_COLLECTIONS) > $@

# get all roles from github
$(CACHE_GH_ROLES): | $(CACHE_DIR)
	@echo "Updating roles cache from github.com"
	@$(GH_ROLES) > $@

# run first time setup
.PHONY: install
install: $(VENV) --config-gh

# upgrade the virtual environment
.PHONY: upgrade
upgrade: $(VENV)
	@pipx -q upgrade --include-injected ansible

# empty the cacheclean
.PHONY: cacheclean
cacheclean:
	@rm -rf $(CACHE_DIR)

# delete the virtual environment
.PHONY: clean
clean: cacheclean
	@pipx -q uninstall ansible

# remove all pip user packages
.PHONY: unpip
unpip:
	@pip freeze --exclude-editable --user |\
		cut -d'@' -f1 | cut -d'=' -f1 | xargs -P $(XARGS_P) -r pip uninstall -y

# --- Development targets ------------------------------------------------------

################################################################################
# new
################################################################################

NAME ?= test

.PHONY: new-role
new-role:
	@gh repo create $(GH_RPFX)$(NAME) \
		--description "Ansible role for setting up $(NAME)" \
		--disable-wiki \
		--public
	@cd $(DIR_ROLES) && \
		ansible-galaxy role init --role-skeleton=$(ROLE_SKELETON) $(NAME) && \
		cd $(NAME) && \
		git init -qb main && git add . && \
		git remote add origin git@github.com:$(GH_USER)/$(GH_RPFX)$(NAME) && \
		git commit -m "feat: Initial commit" && \
		git push -qu origin main && \
		git checkout -qb dev && \
		git push -qu origin dev

################################################################################
# purge
################################################################################
purge-role:
	@rm -rf $(DIR_ROLES)/$(NAME)

################################################################################
# clone
################################################################################

# e.g. git clone git@github.com:jomrr/ansible-collection-test $HOME/src/ansible/collections/jomrr/test
$(DIR_LIST_COLLECTIONS):
	@git clone git@github.com:$(GH_USER)/$(GH_CPFX)$(notdir $@) $@

# clone all collections from github
.PHONY: collections/clone
collections/clone: $(DIR_LIST_COLLECTIONS) | $(CACHE_GH_COLLECTIONS)

# e.g. git clone git@github.com:jomrr/ansible-role-test $HOME/src/ansible/roles/test
$(DIR_LIST_ROLES):
	@git clone git@github.com:$(GH_USER)/$(GH_RPFX)$(notdir $@) $@

# clone all roles from github
.PHONY: roles/clone
roles/clone: $(DIR_LIST_ROLES) | $(CACHE_GH_ROLES)

################################################################################
# checkout or create dev branch
################################################################################

DEV_BRANCHES := $(foreach d,$(COMBINED_REPO_LIST),$(d)/.git/refs/heads/dev)

$(DEV_BRANCHES): $(DIR_LIST_COLLECTIONS) $(DIR_LIST_ROLES)
	@cd $(dir $@)../../.. && \
		git pull     -q && \
		git checkout -qb $(notdir $@) || \
		git checkout -q	 $(notdir $@) && \
		git pull     -q && \
		git push     -qu origin $(notdir $@)

# create dev branch for all repositories
.PHONY: checkout/dev
checkout/dev: $(DEV_BRANCHES)

################################################################################
# pull
################################################################################

PULL_COLLECTIONS_PATHS := $(addsuffix /pull,$(DIR_LIST_COLLECTIONS))

# pull all collection repositories
.PHONY: $(PULL_COLLECTIONS_PATHS)
$(PULL_COLLECTIONS_PATHS):
	@cd $(dir $@) && git pull -q

PULL_ROLES_PATHS := $(addsuffix /pull,$(DIR_LIST_ROLES))

# pull all roles repositories
.PHONY: $(PULL_ROLES_PATHS)
$(PULL_ROLES_PATHS):
	@cd $(dir $@) && git pull -q

# pull all collections and roles
.PHONY: pull
pull: $(PULL_COLLECTIONS_PATHS) $(PULL_ROLES_PATHS)

################################################################################
# update
################################################################################

GIT_DIR_COLLECTIONS	:= $(addsuffix /.git,$(DIR_LIST_COLLECTIONS))
GIT_DIR_ROLES 		:= $(addsuffix /.git,$(DIR_LIST_ROLES))

# targets for .git repository directories to update (pull and push)
.PHONY: $(GIT_DIR_COLLECTIONS) $(GIT_DIR_ROLES)
$(GIT_DIR_ROLES) $(GIT_DIR_COLLECTIONS):
	@cd $(dir $@) && \
		git pull -q origin dev && \
		git push -qu origin dev

# update all collections from github
.PHONY: collections/update
collections/update: $(GIT_DIR_COLLECTIONS) | $(CACHE_GH_COLLECTIONS)

# update all roles from github
.PHONY: roles/update
roles/update: $(GIT_DIR_ROLES) | $(CACHE_GH_ROLES)

################################################################################
# LICENSE
################################################################################

LICENSE_PATHS := $(addsuffix /LICENSE,$(DIR_LIST_ROLES))

T_LICENSE := src=$(ANSIBLE_TPL_DIR)/LICENSE.j2 dest

$(LICENSE_PATHS):
	@$(AM_TEMPLATE) -a "$(T_LICENSE)=$@" $(call cname,$(DIR_ROLES)/,$@)

.PHONY: LICENSE
LICENSE: $(LICENSE_PATHS)

################################################################################
# meta
################################################################################

# e.g. $HOME/src/ansible/roles/test/meta
META_PATHS := $(addsuffix /meta,$(DIR_LIST_ROLES))
# e.g. $HOME/src/ansible/roles/test/meta/main.yml
MMAIN_PATHS := $(addsuffix /main.yml,$(META_PATHS))
# e.g. $HOME/src/ansible/roles/test/meta/requirements.yml
MREQS_PATHS := $(addsuffix /requirements.yml,$(META_PATHS))

T_MMAIN  := src=$(ANSIBLE_TPL_DIR)/meta/main.yml.j2 dest
T_MREQS  := src=$(ANSIBLE_TPL_DIR)/meta/requirements.yml.j2 dest

# meta dir target for all roles
$(META_PATHS):
	@mkdir -p $@

# general meta target for all roles
.PHONY: meta
meta: $(META_PATHS)

# meta/main.yml for all roles
$(MMAIN_PATHS): | $(META_PATHS)
	@$(AM_TEMPLATE) -a "$(T_MMAIN)=$@" $(call cname,$(DIR_ROLES)/,$@)

# meta/requirements.yml for all roles
$(MREQS_PATHS): | $(META_PATHS)
	@$(AM_TEMPLATE) -a "$(T_MREQS)=$@" $(call cname,$(DIR_ROLES)/,$@)

# create all missing meta/main.yml or use make -B (--always-make) to update all
.PHONY: meta/main.yml
meta/main.yml: $(MMAIN_PATHS)

# create all missing meta/requirements.yml or use make -B to update all
.PHONY: meta/requirements.yml
meta/requirements.yml: $(MREQS_PATHS)

################################################################################
# molecule
################################################################################

# e.g. $HOME/src/ansible/roles/test/molecule
MOLECULE_PATHS := $(addsuffix /molecule,$(DIR_LIST_ROLES))

MOLECULE_PLAY := playbooks/molecule.yml

# molecule target for all roles
$(MOLECULE_PATHS):
	@$(ANSIBLE_PLAYBOOK) $(MOLECULE_PLAY) --limit $(call cname,$(DIR_ROLES)/,$@)

.PHONY: molecule
molecule: $(MOLECULE_PATHS)

################################################################################
# pre-commit-config.yaml
################################################################################

PRECOMMIT_PATHS := $(addsuffix /pre-commit-config.yaml,$(DIR_LIST_ROLES))

T_PRECOMMIT := src=$(ANSIBLE_TPL_DIR)/pre-commit-config.yaml.j2 dest

$(PRECOMMIT_PATHS):
	@$(AM_TEMPLATE) -a "$(T_PRECOMMIT)=$@" $(call cname,$(DIR_ROLES)/,$@)

# create all missing pre-commit-config.yaml or use make -B to update all
.PHONY: pre-commit-config
pre-commit-config: $(PRECOMMIT_PATHS)

################################################################################
# pyproject.toml
################################################################################

# absolute paths for all pyproject.toml files
PYPROJECT_PATHS := $(addsuffix /pyproject.toml,$(DIR_LIST_ROLES))

T_PYPROJ  := src=$(ANSIBLE_TPL_DIR)/pyproject.toml.j2 dest

# create all missing pyproject.toml or use make -B (--always-make) to update all
$(PYPROJECT_PATHS):
	@$(AM_TEMPLATE) -a "$(T_PYPROJ)=$@" $(call cname,$@)

.PHONY: pyproject
pyproject: $(PYPROJECT_PATHS)

################################################################################
# README.md
################################################################################

README_PATHS := $(addsuffix /README.md,$(DIR_LIST_ROLES))

T_README  := src=$(ANSIBLE_TPL_DIR)/README.md.j2 dest

$(README_PATHS):
	@$(AM_TEMPLATE) -a "$(T_README) dest=$@" $(call cname,$(DIR_ROLES)/,$@)

.PHONY: README
README: $(README_PATHS)

################################################################################
# requirements.yml
################################################################################

# absolute paths for all $REPO/requirements.yml files
REQUIREMENTS_PATHS := $(foreach d,$(DIR_LIST_ROLES),$(d)/requirements.yml)

T_REQS := src=$(ANSIBLE_TPL_DIR)/requirements.yml.j2 dest

$(REQUIREMENTS_PATHS):
	@$(AM_TEMPLATE) -a "$(T_REQS)=$@" $(notdir $(patsubst %/,%,$(dir $@)))

# create missing requirements.yml or use make -B (--always-make) to update all
requirements: $(REQUIREMENTS_PATHS)

################################################################################
# remove
################################################################################

# list of absolute paths to remove defined via REMOVE
# e.g. $HOME/src/ansible/roles/test/.ansible-lint.yml
PATHS_TO_REMOVE	:= $(foreach d,$(DIR_LIST_ROLES), \
	$(foreach r,$(REMOVE),$(d)/$(r)))

# recursively remove paths defined in REMOVE
.PHONY: $(PATHS_TO_REMOVE)
$(PATHS_TO_REMOVE):
	@rm -rf $@

# remove all paths from REMOVE
.PHONY: remove
remove: $(PATHS_TO_REMOVE)

# --- admin targets ------------------------------------------------------------

.PHONY: me-pc-install me-pc-autoupdate me-pc-run \
	me-commit me-prepare-release me-version me-publish

# install pre-commit hooks
me-pc-install:
	@pre-commit install
	@pre-commit install --hook-type commit-msg

# update pre-commit hooks
me-pc-autoupdate:
	@pre-commit autoupdate

# run pre-commit checks
me-pc-run:
	@pre-commit run --all-files --hook-stage manual

# commit changes to dev branch and push to origin
me-commit:
	@git add .
	@codegpt commit
	@git push origin dev

# prepare a release and merge dev to main
me-prepare-release:
	@git push -u origin dev
	@git checkout main
	@git merge dev
	@git push -u origin main
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
	@git push -u origin main --tags
	@git checkout dev
	@git merge main
	@git push -u origin dev
