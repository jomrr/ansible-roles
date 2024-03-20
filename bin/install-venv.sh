#!/bin/bash

# Function to print usage
usage() {
    echo "Usage: $0 <path_to_venv> <path_to_requirements_file>"
    exit 1
}

# Check if two arguments are passed
if [ "$#" -ne 2 ]; then
    echo "Error: You must provide exactly two arguments."
    usage
fi

# Assign arguments to variables
VENV="$1"
REQS="$2"

# Validate virtual environment path (check if it's a directory)
if [ ! -d "$VENV" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV"
else
    echo "Virtual environment directory exists. Skipping creation."
fi

# Validate requirements file path (check if the file exists)
if [ ! -f "$REQS" ]; then
    echo "Error: Requirements file does not exist at $REQS."
    exit 2
fi

# Activate the virtual environment
source "$VENV/bin/activate"

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing requirements from $REQS..."
pip install --upgrade -r "$REQS"

# Install Ansible collection from Git
echo "Installing Ansible collection..."
ansible-galaxy install -r collections/requirements.yml

# Install pre-commit hooks
if [ -f ".pre-commit-config.yaml" ]; then
    echo "Installing pre-commit hooks..."
    pre-commit install --hook-type commit-msg
    pre-commit install
    pre-commit autoupdate
fi

# Deactivate the virtual environment
deactivate

echo "Setup completed successfully."
