#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Script to lint all shell scripts with ShellCheck

# Exit on error
set -e

# Get directory paths
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if ShellCheck is installed
if ! command -v shellcheck &> /dev/null; then
    echo -e "${RED}ShellCheck is not installed. Please install ShellCheck first.${NC}"
    echo "Installation instructions: https://github.com/koalaman/shellcheck#installing"
    exit 1
fi

# Parse command line arguments
DIRECTORIES=("scripts/aws" "scripts/local" "scripts")
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            shift
            DIRECTORIES=("$1")
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dir <directory>   Lint scripts in the specified directory only"
            echo "  --verbose           Show more detailed output"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  Lint all scripts"
            echo "  $0 --dir scripts/aws  Lint only AWS scripts"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  HPC Bursting Demo - Script Linting   ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Get all shell scripts
FILES=()
for dir in "${DIRECTORIES[@]}"; do
    while IFS= read -r -d '' file; do
        FILES+=("$file")
    done < <(find "$PROJECT_ROOT/$dir" -name "*.sh" -type f -print0)
done

echo -e "${BLUE}Found ${#FILES[@]} shell scripts to check${NC}"
echo ""

# Run ShellCheck on all scripts
ERROR_COUNT=0
SUCCESS_COUNT=0

for file in "${FILES[@]}"; do
    RELATIVE_PATH="${file#$PROJECT_ROOT/}"
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Checking: ${RELATIVE_PATH}${NC}"
    else
        echo -n "."
    fi
    
    if shellcheck -x "$file"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT+1))
        if [ "$VERBOSE" = true ]; then
            echo -e "${GREEN}✓ ${RELATIVE_PATH} passed${NC}"
        fi
    else
        ERROR_COUNT=$((ERROR_COUNT+1))
        if [ "$VERBOSE" = true ]; then
            echo -e "${RED}✗ ${RELATIVE_PATH} failed${NC}"
        else
            echo -e "\n${RED}✗ ${RELATIVE_PATH} failed${NC}"
        fi
    fi
done

# Print summary
echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Linting Summary                      ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${GREEN}Passed: ${SUCCESS_COUNT}${NC}"
echo -e "${RED}Failed: ${ERROR_COUNT}${NC}"
echo ""

# Exit with error if any script failed
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${RED}Linting failed with ${ERROR_COUNT} errors.${NC}"
    exit 1
else
    echo -e "${GREEN}All scripts passed linting!${NC}"
    exit 0
fi