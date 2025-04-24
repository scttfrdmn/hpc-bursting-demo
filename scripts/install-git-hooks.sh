#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Install Git hooks for HPC Bursting Demo

set -e  # Exit on error

# Get the root directory of the repository
REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "Installing Git hooks for HPC Bursting Demo..."

# Configure Git to use our custom hooks directory
git config core.hooksPath .githooks

# Make sure all hooks are executable
chmod +x "$REPO_ROOT/.githooks/"*

echo "✓ Git hooks installed successfully!"
echo "Pre-commit hooks will now run automatically when you commit changes."