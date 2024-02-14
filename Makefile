# Makefile
# ansible-roles

PLAYS := $(shell find playbooks/ -type f -name "*.yml")

# run a playbook
.PHONY: $(PLAYS)
$(PLAYS):
	@ansible-playbook $@

# Git workflow targets
checkout-dev:
	@git checkout dev

start-feature:
	@git checkout -b $(FEATURE) dev

merge-feature-to-dev:
	@git checkout dev
	@git merge $(FEATURE)
	@git branch -d $(FEATURE)

prepare-release:
	@git push origin dev
	@git checkout main
	@git merge dev
	@git push origin main
	@git checkout dev
