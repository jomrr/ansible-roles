# Makefile
# ansible-roles

SHELL				:= /bin/bash
DEBUG				?=

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
ANSIBLE			:= ansible $(DEBUG)
ANSIBLE_INV			:= $(ANSIBLE) -i inventory/
ANSIBLE_INV_TPL		:= $(ANSIBLE_INV) -m ansible.builtin.template
ANSIBLE_PLAYBOOK	:= ansible-playbook $(DEBUG) -i inventory/
JINJA_TPL_DIR		:= playbooks/templates
ROLE_SKELETON		:= $(HOME)/src/ansible/skeleton-ansible-role

# --- Makefile variables -------------------------------------------------------
DIR_CWD				:= $(shell pwd)
#CFG_DEFAULT			:= $(DIR_CWD)/inventory/group_vars/all.yml

COLLS_DIR			:= $(HOME)/src/ansible/collections/$(GH_USER)
ROLES_DIR			:= $(HOME)/src/ansible/roles

XARGS_P 			?= 4
.DEFAULT_GOAL		:= help

ifeq ("$(wildcard $(CACHE_DIR))","")
$(shell mkdir -p $(CACHE_DIR))
endif

ifeq ("$(wildcard $(COLLS_DIR))","")
$(shell mkdir -p $(COLLS_DIR))
endif

ifeq ("$(wildcard $(ROLES_DIR))","")
$(shell mkdir -p $(ROLES_DIR))
endif

ifeq ("$(wildcard $(CACHE_GH_COLLECTIONS))","")
$(shell echo "### UPDATING COLLECTIONS CACHE ###")
$(shell $(GH_COLLECTIONS) > $(CACHE_GH_COLLECTIONS))
endif

COLLECTIONS			:= $(shell cat $(CACHE_GH_COLLECTIONS))

ifeq ("$(wildcard $(CACHE_GH_ROLES))","")
$(shell echo "### UPDATING ROLES CACHE ###")
$(shell $(GH_ROLES) > $(CACHE_GH_ROLES))
endif

ROLES				:= $(shell cat $(CACHE_GH_ROLES))

COLL_DIRS			:= $(addprefix $(COLLS_DIR)/,$(COLLECTIONS))
ROLE_DIRS			:= $(addprefix $(ROLES_DIR)/,$(ROLES))
BOTH_DIRS			:= $(COLL_DIRS) $(ROLE_DIRS)

# use single commit message for all commits or codegpt commit per commit
ifdef MSG
COMMIT_CMD			 = git commit -m "$(MSG)"
else
COMMIT_CMD			:= codegpt commit
endif

# --- Functions ----------------------------------------------------------------

# cname, get the role or collection name from a path
define cname
$(firstword $(subst /, ,$(subst $1,,$2)))
endef

.PRECIOUS: \
	$(COLL_DIRS) \
	$(ROLE_DIRS) \
	$(REQ_GALAXY) \
	$(REQ_PYTHON) \
	$(VENV)

# --- Internal targets ---------------------------------------------------------

# default target
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Setup/Install:"
	@echo "  install                 Install all requirements (pipx, ansible, gh, etc)"
	@echo "  upgrade                 Upgrade ansible in the virtual environment"
	@echo "  cacheclean              Remove GitHub cache"
	@echo "  clean                   Clean cache and uninstall ansible"
	@echo "  uninstall               Remove all pip user packages"
	@echo ""
	@echo "GitHub Operations:"
	@echo "  update-cache            Refresh GitHub repo lists (roles/collections)"
	@echo "  new-role                Create a new role (local skeleton + remote repo)"
	@echo "  purge-role              Delete role locally and remotely"
	@echo "  purge-collection        Delete collection locally and remotely"
	@echo ""
	@echo "Repository Cloning and Sync:"
	@echo "  collections/clone       Clone all collections from GitHub"
	@echo "  roles/clone             Clone all roles from GitHub"
	@echo "  clone                   Clone both collections and roles"
	@echo "  collections/pull        Pull all collections"
	@echo "  roles/pull              Pull all roles"
	@echo "  pull                    Pull everything"
	@echo "  collections/push        Push all collections"
	@echo "  roles/push              Push all roles"
	@echo "  push                    Push everything"
	@echo "  checkout/dev            Ensure dev branch exists in all repos"
	@echo "  commit                  Commit/push all roles"
	@echo "  prepare-release         Merge dev to main and push"
	@echo ""
	@echo "Role File Generation:"
	@echo "  README                  Render all role README.md files"
	@echo "  LICENSE                 Render all LICENSE files"
	@echo "  meta                    Render all meta/ directories"
	@echo "  meta/main.yml           Render all meta/main.yml"
	@echo "  meta/requirements.yml   Render all meta/requirements.yml"
	@echo "  pyproject               Render all pyproject.toml"
	@echo "  requirements            Render all requirements.yml"
	@echo "  molecule                Render all molecule/ for roles"
	@echo "  pre-commit-config       Render all .pre-commit-config.yaml"
	@echo "  templates               Render ALL templates above"
	@echo ""
	@echo "Host Vars:"
	@echo "  host_vars               Generate inventory/host_vars/*.yml for all roles"
	@echo ""
	@echo "Role Clean-up:"
	@echo "  remove                  Remove unneeded files from all roles"
	@echo ""
	@echo "Pre-commit:"
	@echo "  pre-commit-install      Install pre-commit hooks for all roles"
	@echo "  pre-commit-autoupdate   Update pre-commit hooks for all roles"
	@echo "  pre-commit-run          Run pre-commit checks for all roles"
	@echo "  me-pre-commit-install   Install hooks in current dir"
	@echo "  me-pre-commit-autoupdate Update hooks in current dir"
	@echo "  me-pre-commit-run       Run pre-commit in current dir"
	@echo ""
	@echo "Release/Version:"
	@echo "  me-commit               Commit changes (current dir) to dev branch"
	@echo "  me-prepare-release      Prepare/merge release branches"
	@echo "  me-version              Bump version & update changelog"
	@echo "  me-publish              Tag & publish release"

# check for requirements.txt and requirements.yml
$(REQ_PYTHON) $(REQ_GALAXY):
	@echo "$@ not found"; exit 1

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
	@mkdir -p $@

# create collections cache from github
$(CACHE_GH_COLLECTIONS): | $(CACHE_DIR)
	@flock $(CACHE_LOCK) sh -c 'echo "Updating collection cache from github.com"; $(GH_COLLECTIONS) > $@'

# create roles cache from github
$(CACHE_GH_ROLES): | $(CACHE_DIR)
	@flock $(CACHE_LOCK) sh -c 'echo "Updating role cache from github.com"; $(GH_ROLES) > $@'

# update all github cache
.PHONY: update-cache
update-cache: $(CACHE_GH_COLLECTIONS) $(CACHE_GH_ROLES)

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
.PHONY: uninstall
uninstall: clean
	@pip freeze --exclude-editable --user |\
		cut -d'@' -f1 | cut -d'=' -f1 | xargs -P $(XARGS_P) -r pip uninstall -y

# --- Development targets ------------------------------------------------------

################################################################################
# new role
################################################################################

NAME		?= test
DESC		?= "Ansible role for setting up $(NAME)"
ROLE_DIR	:= $(ROLES_DIR)/$(NAME)
REPO_NAME	:= $(GH_RPFX)$(NAME)
GH_REPO		:= $(GH_USER)/$(REPO_NAME)
GH_URL		:= git@github.com:$(GH_REPO)

$(ROLE_DIR):
	@cd $(ROLES_DIR) && \
		ansible-galaxy role init --role-skeleton=$(ROLE_SKELETON) $(NAME)

$(ROLE_DIR)/.git: | $(ROLE_DIR)
	@cd $(ROLE_DIR) && \
		git init -qb main && \
		git remote add origin git@github.com:$(GH_REPO) && \
		echo "# Ansible Role: $(NAME)" > README.md && \
		git add README.md && \
		git commit -m "docs: add README" && \
		git push -u origin main && \
		git checkout -b dev && \
		git push -u origin dev && \
		git branch --set-upstream-to=origin/dev dev

.PHONY: new-gh-role
new-gh-role:
	@if ! grep -qxF '$(NAME)' $(CACHE_GH_ROLES); then \
		echo "Creating new role repo github.com/$(GH_REPO)"; \
		if gh repo create $(GH_REPO) \
			--description "$(DESC)" \
			--disable-wiki \
			--public; then \
			echo "Repository $(GH_REPO) created."; \
			echo "$(NAME)" >> $(CACHE_GH_ROLES); \
		else \
			echo "Error creating Repository $(GH_REPO)." >&2; \
			exit 1; \
		fi; \
	else \
		echo "Repository $(NAME) existiert bereits im Cache."; \
	fi

.PHONY: new-role
new-role: new-gh-role | $(ROLE_DIR)/.git

# ################################################################################
# # purge
# ################################################################################

.PHONY: purge-collection
purge-collection:
	@rm -rf "$(COLLS_DIR)/$(NAME)"
	@gh repo delete "$(GH_CPFX)$(NAME)" --yes
	sed -i "/^$(NAME)$$/d" "$(CACHE_GH_COLLECTIONS)"

.PHONY: purge-role
purge-role:
	@rm -rf "$(ROLES_DIR)/$(NAME)"
	@gh repo delete "$(GH_RPFX)$(NAME)" --yes
	sed -i "/^$(NAME)$$/d" "$(CACHE_GH_ROLES)"

# ################################################################################
# # clone
# ################################################################################

# create collections directory
$(COLLS_DIR):
	@mkdir -p $@

# create roles directory
$(ROLES_DIR):
	@mkdir -p $@

# clone rule for collections and roles
define clone_rule
$1/%: $2 | $1
	@if [ -d "$$@" ] && [ ! -d "$$@/.git" ]; then \
		echo "Warning: $$@ exists but is not a git repo. Deleting and recloning..."; \
		rm -rf "$$@"; \
	fi; \
	if [ ! -d "$$@" ]; then \
		git clone git@github.com:$(GH_USER)/$3$$(notdir $$@) "$$@"; \
	else \
		echo "Skipping clone for $$(notdir $$@), directory already exists."; \
	fi
endef

$(eval $(call clone_rule,$(COLLS_DIR),$(CACHE_GH_COLLECTIONS),$(GH_CPFX)))
$(eval $(call clone_rule,$(ROLES_DIR),$(CACHE_GH_ROLES),$(GH_RPFX)))

# clone all collections from github
.PHONY: collections/clone
collections/clone: $(COLL_DIRS) | $(CACHE_GH_COLLECTIONS)

# clone all roles from github
.PHONY: roles/clone
roles/clone: $(ROLE_DIRS) | $(CACHE_GH_ROLES)

# clone all collections and roles from github
clone: collections/clone roles/clone

# ################################################################################
# # checkout or create dev branch
# ################################################################################

DEV_BRANCHES := $(foreach d,$(BOTH_DIRS),$(d)/.git/refs/heads/dev)

$(DEV_BRANCHES): %/.git/refs/heads/dev: %
	cd "$*" && \
	git pull -q && \
	(git checkout -b dev || git checkout dev) && \
	git branch --set-upstream-to=origin/dev dev && \
	git branch --set-upstream-to=origin/main main && \
	git pull && \
	git push -u origin dev

# create dev branch for all repositories
.PHONY: checkout/dev
checkout/dev: $(DEV_BRANCHES)

# ################################################################################
# # commit
# ################################################################################

COMMIT_PATHS := $(addsuffix /commit,$(ROLE_DIRS))

.PHONY: $(COMMIT_PATHS)
$(COMMIT_PATHS): %/commit:
	cd "$*" && \
	git pull && \
	git add . && \
	$(COMMIT_CMD) || true && \
	git pull && \
	git push -u origin dev

# commit all collections and roles
.PHONY: commit
commit: $(COMMIT_PATHS)

# ################################################################################
# # prepare-release
# ################################################################################

PREPARE_RELEASE_PATHS := $(addsuffix /prepare-release,$(ROLE_DIRS))

.PHONY: $(PREPARE_RELEASE_PATHS)
$(PREPARE_RELEASE_PATHS): %/prepare-release:
	cd "$*" && \
	git push -u origin dev && \
	git checkout main && \
	git merge dev && \
	git push -u origin main && \
	git checkout dev

# prepare a release for all collections and roles
.PHONY: prepare-release
prepare-release: $(PREPARE_RELEASE_PATHS)

# ################################################################################
# # push
# ################################################################################

PUSH_COLLECTIONS_PATHS := $(addsuffix /push,$(COLL_DIRS))
PUSH_ROLES_PATHS := $(addsuffix /push,$(ROLE_DIRS))

# push all collection and role repositories
.PHONY: $(PUSH_ROLES_PATHS) $(PUSH_COLLECTIONS_PATHS)
$(PUSH_ROLES_PATHS) $(PUSH_COLLECTIONS_PATHS): %/push:
	@cd "$*" && git push -u origin dev

.PHONY: collections/push
collections/push: $(PUSH_COLLECTIONS_PATHS)

.PHONY: roles/push
roles/push: $(PUSH_ROLES_PATHS)

# push all collections and roles
.PHONY: push
push: $(PUSH_COLLECTIONS_PATHS) $(PUSH_ROLES_PATHS)

# ################################################################################
# # pull
# ################################################################################

PULL_COLLECTIONS_PATHS := $(addsuffix /pull,$(COLL_DIRS))
PULL_ROLES_PATHS := $(addsuffix /pull,$(ROLE_DIRS))

# pull all repositories
.PHONY: $(PULL_COLLECTIONS_PATHS) $(PULL_ROLES_PATHS)
$(PULL_COLLECTIONS_PATHS) $(PULL_ROLES_PATHS): %/pull: | %
	@cd "$*" && git pull

.PHONY: collections/pull
collections/pull: $(PULL_COLLECTIONS_PATHS)

.PHONY: roles/pull
roles/pull: $(PULL_ROLES_PATHS)

# pull all collections and roles
.PHONY: pull
pull: $(PULL_COLLECTIONS_PATHS) $(PULL_ROLES_PATHS)

# ################################################################################
# # pre-commit
# ################################################################################

# dynamic pre-commit targets per role for all roles
define declare_precommit_targets
$(foreach role,$(ROLES), \
  $(eval $(ROLES_DIR)/$(role)/pre-commit-install: $(ROLES_DIR)/$(role)/.pre-commit-config.yaml ; \
    cd $(ROLES_DIR)/$(role) && pre-commit install --hook-type pre-commit && pre-commit install --hook-type commit-msg \
  ) \
  $(eval $(ROLES_DIR)/$(role)/pre-commit-autoupdate: $(ROLES_DIR)/$(role)/.pre-commit-config.yaml ; \
    cd $(ROLES_DIR)/$(role) && pre-commit autoupdate \
  ) \
  $(eval $(ROLES_DIR)/$(role)/pre-commit-run: $(ROLES_DIR)/$(role)/pre-commit-autoupdate ; \
    cd $(ROLES_DIR)/$(role) && pre-commit run --all-files --hook-stage manual \
  ) \
)
endef

$(eval $(call declare_precommit_targets))

# pre-commit targets for all roles
.PHONY: pre-commit-install pre-commit-autoupdate pre-commit-run
pre-commit-install: $(foreach role,$(ROLES),$(ROLES_DIR)/$(role)/pre-commit-install)
pre-commit-autoupdate: $(foreach role,$(ROLES),$(ROLES_DIR)/$(role)/pre-commit-autoupdate)
pre-commit-run: $(foreach role,$(ROLES),$(ROLES_DIR)/$(role)/pre-commit-run)

# ################################################################################
# # remove
# ################################################################################

REMOVE			:= .ansible-lint.yml .github .yamllint.yml requirements.txt
REMOVE			+= CONTRIBUTING.md .git/hooks/*

REMOVE_TARGETS	:= $(addsuffix /remove,$(ROLE_DIRS))

# dynamic remove targets per role for all roles
.PHONY: $(REMOVE_TARGETS)
$(REMOVE_TARGETS): %/remove:
	@for file in $(REMOVE); do \
		if [ -n "$$file" ] && [ "$$file" != "/" ]; then \
			echo "Removing $*/$$file"; \
			rm -rf "$*/$$file"; \
		fi; \
	done

# remove all paths from REMOVE for all roles
.PHONY: remove
remove: $(REMOVE_TARGETS)

# --- template targets ---------------------------------------------------------

TEMPLATE_TARGETS := meta/main.yml meta/requirements.yml molecule LICENSE README.md .pre-commit-config.yaml pyproject.toml requirements.yml

# Generate Targets for each role and template.
# Touch the target file after ansible template run to avoid re-running,
# if ansible template module did not change the file.
define declare_template_targets
$(foreach role,$(ROLES), \
  $(foreach tmpl,$(TEMPLATE_TARGETS), \
    $(eval $(ROLES_DIR)/$(role)/$(tmpl): playbooks/templates/$(tmpl).j2 inventory/host_vars/$(role).yml) \
    $(eval $(ROLES_DIR)/$(role)/$(tmpl):
	@echo "Generating $(tmpl) for $(role)"
	@$$(ANSIBLE_INV_TPL) -a "src=playbooks/templates/$(tmpl).j2 dest=$$@" $(role)
	@touch $$@
    ) \
  ) \
)
endef

$(eval $(call declare_template_targets))

# Aggregat-Targets pro Template, damit make <template> alles baut
$(foreach tmpl,$(TEMPLATE_TARGETS), \
  $(eval .PHONY: $(tmpl)) \
  $(eval $(tmpl): $(foreach role,$(ROLES),$(ROLES_DIR)/$(role)/$(tmpl))) \
)

# Optional: Master-Aggregat für alles
.PHONY: templates
templates: $(foreach tmpl,$(TEMPLATE_TARGETS),$(tmpl))

# --- inventory and host_vars targets ------------------------------------------

# Target to generate host vars for role
inventory/host_vars/%.yml:
	@echo "Generating host vars for $(notdir $@)"
	@$(ANSIBLE_INV_TPL) -a "src=$(JINJA_TPL_DIR)/host_vars.yml.j2 dest=$(DIR_CWD)/$@" $*

# Host var targets
HV_TARGETS := $(foreach role,$(ROLES),inventory/host_vars/$(role).yml)

# Aggregate target to generate host vars for all roles
.PHONY: host_vars
host_vars: $(HV_TARGETS)

# --- meta targets -------------------------------------------------------------

.PHONY: me-pre-commit-install me-pre-commit-autoupdate me-pre-commit-run

# install pre-commit hooks
me-pre-commit-install:
	@pre-commit install --hook-type pre-commit
	@pre-commit install --hook-type commit-msg

# update pre-commit hooks
me-pre-commit-autoupdate:
	@pre-commit autoupdate

# run pre-commit
me-pre-commit-run:
	@pre-commit run --all-files --hook-stage manual

.PHONY: me-commit me-prepare-release me-version me-publish

# commit changes to dev branch and push to origin
me-commit:
	@git add .
	@$(COMMIT_CMD)
	@git push origin dev

# prepare a release and merge dev to main
me-prepare-release:
	@git push --set-upstream origin dev
	@git checkout main
	@git merge --no-ff dev || (echo "Merge failed, aborting" && exit 1)
	@git push --set-upstream origin main
	@git checkout dev

# bump the version number and update the changelog
me-version:
	@git checkout main
	@semantic-release version
	@git checkout dev
	@git merge main

# create a new git tag and build the distribution files
me-publish:
	@git checkout main
	@semantic-release publish
	@git push --set-upstream origin main --tags
	@git checkout dev
	@git merge main
	@git push --set-upstream origin dev
