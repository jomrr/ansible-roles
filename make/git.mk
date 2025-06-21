# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/git.mk

NAMESPACE			:= jomrr
VCS_URL				:= git@git.mauer.in:$(NAMESPACE)

# --- macro for git-actions as pattern <type>/<name>/<action> ------------------
define declare_git_targets

# Clone-Target
$(1)/$(2)/clone:
	@if [ -d $(1)/$(2) ] && [ ! -d $(1)/$(2)/.git ]; then \
		echo "[$(2)] Exists but is not a git repo. Deleting and recloning..."; \
		rm -rf $(1)/$(2); \
	fi
	@if [ ! -d $(1)/$(2) ]; then \
		echo "[$(2)] Cloning $(VCS_URL)/$(3)-$(2)..."; \
		git clone $(VCS_URL)/$(3)-$(2) $$(abspath $(1)/$(2)); \
	else \
		echo "[$(2)] Already exists. Skipping clone."; \
	fi

# Commit-Target
$(1)/$(2)/commit:
	@if [ -d $(1)/$(2)/.git ]; then \
		cd $(1)/$(2); \
		if git status --porcelain | grep -q .; then \
			echo "[$(2)] Committing changes..."; \
			git pull; \
			git add .; \
			if [ -n "$$COMMIT_CMD" ]; then eval "$$COMMIT_CMD"; else codegpt commit; fi; \
			git pull; \
			git push -u origin dev; \
		else \
			echo "[$(2)] No changes to commit."; \
		fi \
	else \
		echo "[$(2)] is not a git repository. Skipping."; \
	fi

# Push-Target
$(1)/$(2)/push:
	@if [ -d $(1)/$(2)/.git ]; then \
		cd $(1)/$(2); \
		if git remote | grep -qxF origin; then \
			echo "[$(2)] Pushing to origin dev..."; \
			git push -u origin dev; \
		else \
			echo "[$(2)] No 'origin' remote, skipping push."; \
		fi \
	else \
		echo "[$(2)] is not a git repository. Skipping."; \
	fi

# Pull-Target
$(1)/$(2)/pull:
	@if [ -d $(1)/$(2)/.git ]; then \
		cd $(1)/$(2); \
		echo "[$(2)] Pulling latest changes..."; \
		git pull; \
	else \
		echo "[$(2)] is not a git repository. Skipping."; \
	fi

# Status-Target
$(1)/$(2)/status:
	@if [ -d $(1)/$(2)/.git ]; then \
		cd $(1)/$(2); \
		git status; \
	else \
		echo "[$(2)] is not a git repository. Skipping."; \
	fi

# Checkout-Dev-Target
$(1)/$(2)/checkout-dev:
	@if [ -d $(1)/$(2)/.git ]; then \
		cd $(1)/$(2); \
		echo "[$(2)] Ensuring dev branch exists..."; \
		git pull -q; \
		if ! git rev-parse --verify dev >/dev/null 2>&1; then \
			git checkout -b dev || git checkout dev; \
			git branch --set-upstream-to=origin/dev dev; \
		fi; \
		git branch --set-upstream-to=origin/main main; \
		git pull; \
		git push -u origin dev; \
	else \
		echo "[$(2)] is not a git repository. Skipping."; \
	fi

# Prepare-Release-Target
$(1)/$(2)/prepare-release:
	@if [ -d $(1)/$(2)/.git ]; then \
		cd $(1)/$(2); \
		echo "[$(2)] Preparing release (merge dev into main)..."; \
		git push -u origin dev; \
		git checkout main; \
		git merge dev; \
		git push -u origin main; \
		git checkout dev; \
	else \
		echo "[$(2)] is not a git repository. Skipping."; \
	fi

endef

$(foreach role,$(ROLES),      $(eval $(call declare_git_targets,roles,$(role),ansible-role)))
$(foreach coll,$(COLLECTIONS),$(eval $(call declare_git_targets,collections,$(coll),ansible-collection)))

.PHONY: collections/clone collections/commit collections/push collections/pull collections/status collections/checkout-dev collections/prepare-release
collections/clone:           $(COLLECTIONS:%=collections/%/clone)
collections/commit:          $(COLLECTIONS:%=collections/%/commit)
collections/push:            $(COLLECTIONS:%=collections/%/push)
collections/pull:            $(COLLECTIONS:%=collections/%/pull)
collections/status:          $(COLLECTIONS:%=collections/%/status)
collections/checkout-dev:    $(COLLECTIONS:%=collections/%/checkout-dev)
collections/prepare-release: $(COLLECTIONS:%=collections/%/prepare-release)

.PHONY: roles/clone roles/commit roles/push roles/pull roles/status roles/checkout-dev roles/prepare-release
roles/clone:                 $(ROLES:%=roles/%/clone)
roles/commit:                $(ROLES:%=roles/%/commit)
roles/push:                  $(ROLES:%=roles/%/push)
roles/pull:                  $(ROLES:%=roles/%/pull)
roles/status:                $(ROLES:%=roles/%/status)
roles/checkout-dev:          $(ROLES:%=roles/%/checkout-dev)
roles/prepare-release:       $(ROLES:%=roles/%/prepare-release)

.PHONY: clone commit push pull status checkout-dev prepare-release
clone:           roles/clone collections/clone
commit:          roles/commit collections/commit
push:            roles/push collections/push
pull:            roles/pull collections/pull
status:          roles/status collections/status
checkout-dev:    roles/checkout-dev collections/checkout-dev
prepare-release: roles/prepare-release collections/prepare-release
