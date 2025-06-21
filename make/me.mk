# vim: set filetype=makefile,expandtab,shiftwidth=4,softtabstop=4,textwidth=80:
# file: make/me.mk
# Makefile for managing development tasks

# use single commit message for all commits or codegpt commit per commit
ifdef MSG
COMMIT_CMD	 = git commit -m "$(MSG)"
else
COMMIT_CMD	:= codegpt commit
endif

# install pre-commit hooks
.PHONY: me-pre-commit-install
me-pre-commit-install:
	@pre-commit install --hook-type pre-commit
	@pre-commit install --hook-type commit-msg

# update pre-commit hooks
.PHONY: me-pre-commit-autoupdate
me-pre-commit-autoupdate:
	@pre-commit autoupdate

# run pre-commit
.PHONY: me-pre-commit-run
me-pre-commit-run:
	@pre-commit run --all-files --hook-stage manual

# commit changes to dev branch and push to origin
.PHONY: me-commit
me-commit:
	@git add .
	@$(COMMIT_CMD)
	@git push origin dev

# prepare a release and merge dev to main
.PHONY: me-prepare-release
me-prepare-release:
	@git push --set-upstream origin dev
	@git checkout main
	@git merge --no-ff dev || (echo "Merge failed, aborting" && exit 1)
	@git push --set-upstream origin main
	@git checkout dev

# bump the version number and update the changelog
.PHONY: me-version
me-version:
	@git checkout main
	@semantic-release version
	@git checkout dev
	@git merge main

# create a new git tag and build the distribution files
.PHONY: me-publish
me-publish:
	@git checkout main
	@semantic-release publish
	@git push --set-upstream origin main --tags
	@git checkout dev
	@git merge main
	@git push --set-upstream origin dev
