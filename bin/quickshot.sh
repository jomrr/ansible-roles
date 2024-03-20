#!/bin/bash

# Usage: ./quickshot.sh <ROLEPATH> <LIMIT>

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ROLEPATH> <LIMIT>"
    exit 1
fi

ROLEPATH=$1
LIMIT=$2

cd "$ROLEPATH/ansible-role-$LIMIT" || exit 1
git checkout dev
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit autoupdate
git add .
codegpt commit
git push -u origin  dev
git checkout main
git merge dev
git push -u origin main
git checkout dev
