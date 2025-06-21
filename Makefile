# Makefile
# ansible-roles

SHELL				:= /bin/bash

# --- Requirements and virtual env ---------------------------------------------
REQ_DNF				:= findutils git-core python3-virtualenv
REQ_PYTHON			:= requirements.txt
REQ_GALAXY			:= requirements.yml
VENV				:= .ansible/venv
PIP					:= $(VENV)/bin/pip

# --- Ansible variables --------------------------------------------------------
ANSIBLE				:= $(VENV)/bin/ansible
GALAXY				:= $(VENV)/bin/ansible-galaxy
TEMPLATE			:= $(ANSIBLE) -m ansible.builtin.template
TEMPLATES_DIR		:= playbooks/templates

# --- Target variables ---------------------------------------------------------
COLLECTIONS_DIR		:= ../collections/$(NAMESPACE)
ROLES_DIR			:= ../roles

COLLECTIONS			:= $(notdir $(wildcard $(COLLECTIONS_DIR)/*))
ROLES				:= $(notdir $(wildcard $(ROLES_DIR)/*))

# --- Default target -----------------------------------------------------------
.DEFAULT_GOAL		:= help

.PRECIOUS: \
	$(COLLECTIONS_DIR) \
	$(ROLES_DIR) \
	$(REQ_GALAXY) \
	$(REQ_PYTHON) \
	$(VENV)

# --- General targets ----------------------------------------------------------

# help target to display available targets
.PHONY: help
help:
	@echo "Usage: make [target]"

$(COLLECTIONS_DIR):
	@mkdir -p $@

$(ROLES_DIR):
	@mkdir -p $@

# check for requirements.txt and requirements.yml
$(REQ_PYTHON) $(REQ_GALAXY):
	@echo "$@ not found"; exit 1

.ansible:
	@mkdir -p $@

# install dnf packages
.PHONY: .req-dnf
.req-dnf:
	@sudo dnf install -qy $(REQ_DNF)

.req-python: $(REQ_PYTHON) | $(VENV)
	@echo "Installing Python requirements from $(REQ_PYTHON)"
	@$(PIP) install --upgrade pip
	@$(PIP) install -r $(REQ_PYTHON)

.req-galaxy: $(REQ_GALAXY) | $(VENV)
	@echo "Installing Galaxy requirements from $(REQ_GALAXY)"
	@$(GALAXY) install -fr $(REQ_GALAXY)

# create virtual environment and install requirements
$(VENV): | .ansible
	@echo "Creating virtual environment in $(VENV)"
	@python3 -m venv $(VENV)

install upgrade: .req-dnf .req-python .req-galaxy | $(COLLECTIONS_DIR) $(ROLES_DIR)
	@echo "Virtual environment and requirements $@ complete."

# --- Included targets ---------------------------------------------------------

$(foreach mk,$(wildcard make/*.mk),$(eval include $(mk)))

# ################################################################################
# # new role
# ################################################################################

# NAME		?= test
# DESC		?= "Ansible role for setting up $(NAME)"
# ROLE_DIR	:= $(ROLES_DIR)/$(NAME)
# REPO_NAME	:= $(GH_RPFX)$(NAME)
# GH_REPO		:= $(GH_USER)/$(REPO_NAME)
# GH_URL		:= git@github.com:$(GH_REPO)

# $(ROLE_DIR): | $(ROLES_DIR)
# 	@cd $(ROLES_DIR) && \
# 		ansible-galaxy role init --role-skeleton=$(ROLE_SKELETON) $(NAME)

# $(ROLE_DIR)/.git: | $(ROLE_DIR)
# 	@bin/git-op.sh init-role $(role_path) $(GH_REPO) $(NAME)

# .PHONY: new-gh-role
# new-gh-role:
# 	@if ! grep -qxF '$(NAME)' $(CACHE_GH_ROLES); then \
# 		echo "Creating new role repo github.com/$(GH_REPO)"; \
# 		if gh repo create $(GH_REPO) \
# 			--description "$(DESC)" \
# 			--disable-wiki \
# 			--public; then \
# 			echo "Repository $(GH_REPO) created."; \
# 			echo "$(NAME)" >> $(CACHE_GH_ROLES); \
# 		else \
# 			echo "Error creating Repository $(GH_REPO)." >&2; \
# 			exit 1; \
# 		fi; \
# 	else \
# 		echo "Repository $(NAME) existiert bereits im Cache."; \
# 	fi

# .PHONY: new-role
# new-role: new-gh-role | $(ROLE_DIR)/.git

# # --- template targets ---------------------------------------------------------

# # List of template files to be generated for each role using Ansible templates.
# TEMPLATE_TARGETS := \
# 	.gitignore \
# 	.pre-commit-config.yaml \
# 	meta/main.yml \
# 	meta/requirements.yml \
# 	LICENSE \
# 	README.md \
# 	molecule \
# 	pyproject.toml \
# 	requirements.yml
