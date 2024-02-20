# Makefile
# ansible-roles

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
FEATURE				?= feature/$(shell date +%Y%m%d%H%M%S)
# --- Makefile variables -------------------------------------------------------
BASEDIR				:= $(shell pwd)
ROLEDIR				:= $(realpath ~/src/ansible/roles)
PLAYDIR				:= $(BASEDIR)/playbooks
PLAYBOOKS			:= $(basename $(notdir $(wildcard $(PLAYDIR)/*.yml)))
# --- Makefile targets ---------------------------------------------------------

# default target
.PHONY: help
help:
	@echo "Usage: make <target> [LIMIT=<hostname or group>]"
	@echo ""
	@echo "Targets:"
	@echo "  help                 Show this help"
	@echo ""
	@echo "  # --- python virtual environment targets -------------------------"
	@echo ""
	@echo "  install              Install the python virtual environment"
	@echo "  update               Update the python virtual environment"
	@echo "  clean                Remove the python virtual environment"
	@echo ""
	@echo "  # --- ansible targets --------------------------------------------"
	@echo ""
	@echo "  all                  Run all playbooks"
	@echo "  docs                 Run contributing, license, readme playbooks"
	@echo "  contributing         Run the contributing playbook"
	@echo "  license              Run the license playbook"
	@echo "  readme               Run the readme playbook"
	@echo "  meta_main            Run the meta_main playbook"
	@echo "  meta_requirements    Run the meta_requirements playbook"
	@echo "  remove               Run the remove playbook"
	@echo ""
	@echo "  # --- git targets ------------------------------------------------"
	@echo ""
	@echo "  checkout-dev         Checkout the dev branch"
	@echo "  start-feature        Start a new feature branch"
	@echo "  merge-feature-to-dev Merge a feature branch to dev"
	@echo "  commit               Stage and commit changes to current branch"
	@echo "  prepare-release      Prepare a release and merge dev to main"

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

$(BASEDIR)/inventory/group_vars/all/meta.yml:
	@echo "default config in inventory/group_vars/all/meta.yml not found"
	@exit 1

$(ROLEDIR): $(BASEDIR)/inventory/group_vars/all/meta.yml
	@echo "ansible roles directory not found"
	@exit 1

all: comment contributing license meta_main meta_requirements molecule pre-commit-config pyproject readme remove

docs: license readme

$(PLAYBOOKS): $(ROLEDIR)
	$(ANSIBLE_PLAYBOOK) $(PLAYDIR)/$@.yml \
		$(if $(EXTRA_VARS),--extra-vars "$(EXTRA_VARS)") \
		--limit=$(LIMIT) \
		$(if $(SKIP_TAGS),--skip-tags $(SKIP_TAGS)) \
		$(if $(TAGS),--tags $(TAGS))

# --- git targets --------------------------------------------------------------
.PHONY: checkout-dev commit start-feature merge-feature-to-dev prepare-release

# checkout the dev branch
checkout-dev:
	@git checkout dev

# commit changes to the current branch
commit:
	@git add .
	@git commit

# start a new feature branch
start-feature:
	@git checkout -b $(FEATURE) dev

# merge a feature branch to dev
merge-feature-to-dev:
	@git checkout dev
	@git merge $(FEATURE)
	@git branch -d $(FEATURE)

# prepare a release and merge dev to main
prepare-release:
	@git push origin dev
	@git checkout main
	@git merge dev
	@git push origin main
	@git checkout dev

# bump the version number and update the changelog
version:
	@git checkout main
	@semantic-release version
	@git checkout dev
	@git merge main

# create a new Git tag and build the distribution files
publish:
	@git checkout main
	@semantic-release publish
	@git push origin main --tags
	@git checkout dev
