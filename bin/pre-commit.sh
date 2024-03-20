#!/bin/bash

# Usage: ./pre-commit.sh <command> <ROLEDIR>
# command: install | autoupdate

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <command> <ROLEDIR>"
    echo "command: install | autoupdate"
    exit 1
fi

COMMAND=$1
ROLEDIR=$2

pre_commit_install() {
    for dir in "$ROLEDIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/.pre-commit-config.yaml" ]; then
            echo "Installing pre-commit in $dir"
            cd "$dir" || exit
            pre-commit install || rm -rf .git/hooks && pre-commit install
            pre-commit install --hook-type commit-msg
        fi
    done
}

pre_commit_autoupdate() {
    for dir in "$ROLEDIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/.pre-commit-config.yaml" ]; then
            cd "$dir" || exit
            # Check if dev branch exists locally or on the remote
            if git show-ref --verify --quiet refs/heads/dev || git ls-remote --heads --quiet --exit-code origin dev; then
                echo "Updating .pre-commit-config.yaml in $dir"
                git checkout dev
                pre-commit autoupdate
                # Check if there are changes to commit
                if git diff --cached --exit-code --quiet; then
                    echo "No changes to commit in $dir"
                else
                    git add .pre-commit-config.yaml
                    git commit -m "chore: update .pre-commit-config.yaml"
                    git push -u origin dev
                fi
            else
                echo "Branch 'dev' does not exist in $dir, skipping."
            fi
        fi
    done
}

case $COMMAND in
    install)
        pre_commit_install
        ;;
    autoupdate)
        pre_commit_autoupdate
        ;;
    *)
        echo "Invalid command: $COMMAND"
        echo "Usage: $0 <command> <ROLEDIR>"
        echo "command: install | autoupdate"
        exit 2
        ;;
esac
