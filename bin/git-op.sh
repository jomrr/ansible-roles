#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 <operation> <repo_path> [args...]"
    echo "Supported operations: clone, commit, push, pull, status, checkout-dev, prepare-release, init-role"
    exit 1
}

clone_repo() {
    declare repo_dir="$1"
    declare git_url="$2"
    if [[ -d "$repo_dir" && ! -d "$repo_dir/.git" ]]; then
        echo "[$repo_dir] Exists but is not a git repo. Deleting and recloning..."
        rm -rf "$repo_dir"
    fi
    if [[ ! -d "$repo_dir" ]]; then
        echo "[$repo_dir] Cloning $git_url..."
        git clone "$git_url" "$repo_dir"
    else
        echo "[$repo_dir] Already exists. Skipping clone."
    fi
}

commit_repo() {
    declare repo="$1"
    if git status --porcelain | grep -q .; then
        echo "[$repo] Committing changes..."
        git pull
        git add .
        if [[ -n "${COMMIT_CMD:-}" ]]; then
            eval "$COMMIT_CMD"
        else
            codegpt commit
        fi
        git pull
        git push -u origin dev
    else
        echo "[$repo] No changes to commit."
    fi
}

push_repo() {
    declare repo="$1"
    if git remote | grep -qxF origin; then
        echo "[$repo] Pushing to origin dev..."
        git push -u origin dev
    else
        echo "[$repo] No 'origin' remote, skipping push."
    fi
}

pull_repo() {
    declare repo="$1"
    echo "[$repo] Pulling latest changes..."
    git pull
}

status_repo() {
    declare repo="$1"
    git status
}

checkout_dev_repo() {
    declare repo="$1"
    echo "[$repo] Ensuring dev branch exists..."
    git pull -q
    if ! git rev-parse --verify dev >/dev/null 2>&1; then
        git checkout -b dev || git checkout dev
        git branch --set-upstream-to=origin/dev dev
    fi
    git branch --set-upstream-to=origin/main main
    git pull
    git push -u origin dev
}

prepare_release_repo() {
    declare repo="$1"
    echo "[$repo] Preparing release (merge dev into main)..."
    git push -u origin dev
    git checkout main
    git merge dev
    git push -u origin main
    git checkout dev
}

init_role_repo() {
    declare repo="$1"
    declare gh_repo="${2:-}"
    declare name="${3:-}"
    cd "$repo"
    git init -qb main
    git remote add origin "git@github.com:${gh_repo}"
    echo "# Ansible Role: ${name}" > README.md
    git add README.md
    git commit -m "docs: add README"
    git push -u origin main
    git checkout -b dev
    git push -u origin dev
    git branch --set-upstream-to=origin/dev dev
}

main() {
    if [[ $# -lt 2 ]]; then usage; fi
    declare op="$1"
    declare repo="$2"
    shift 2

    # Special case for init-role (repo may not have .git yet)
    if [[ "$op" == "init-role" ]]; then
        init_role_repo "$repo" "${1:-}" "${2:-}"
        exit 0
    fi

    if [[ ! -d "$repo/.git" ]]; then
        echo "[$repo] is not a git repository. Skipping."
        exit 0
    fi

    cd "$repo"

    case "$op" in
        clone)              clone_repo "$repo" "$3" ;;  # expects git url as $3
        commit)             commit_repo "$repo" ;;
        push)               push_repo "$repo" ;;
        pull)               pull_repo "$repo" ;;
        status)             status_repo "$repo" ;;
        checkout-dev)       checkout_dev_repo "$repo" ;;
        prepare-release)    prepare_release_repo "$repo" ;;
        *)                  usage ;;
    esac
}

main "$@"
