#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Master script for running all tests

# Ensure we exit on any error
set -e

# Determine the tests directory
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
    echo "BATS is not installed. Please install BATS first."
    echo "Installation instructions: https://github.com/bats-core/bats-core#installation"
    exit 1
fi

# Install BATS libraries if they don't exist
BATS_SUPPORT_DIR="$TESTS_DIR/test_libs/bats-support"
BATS_ASSERT_DIR="$TESTS_DIR/test_libs/bats-assert"

if [ ! -d "$BATS_SUPPORT_DIR" ]; then
    echo "Installing bats-support..."
    mkdir -p "$TESTS_DIR/test_libs"
    git clone https://github.com/bats-core/bats-support.git "$BATS_SUPPORT_DIR"
fi

if [ ! -d "$BATS_ASSERT_DIR" ]; then
    echo "Installing bats-assert..."
    mkdir -p "$TESTS_DIR/test_libs"
    git clone https://github.com/bats-core/bats-assert.git "$BATS_ASSERT_DIR"
fi

# Parse command line arguments
run_specific_test=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            shift
            run_specific_test="$1"
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --test <test_name>  Run a specific test file"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  Run all tests"
            echo "  $0 --test cleanup_aws_resources  Run cleanup_aws_resources.bats tests"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
done

# Define color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  HPC Bursting Demo - Test Suite      ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Run the tests
if [ -n "$run_specific_test" ]; then
    # Run specific test
    if [ -f "$TESTS_DIR/bats/${run_specific_test}.bats" ]; then
        echo -e "${BLUE}Running test: ${run_specific_test}.bats${NC}"
        bats "$TESTS_DIR/bats/${run_specific_test}.bats"
    else
        echo -e "${RED}Test file not found: ${run_specific_test}.bats${NC}"
        exit 1
    fi
else
    # Run all tests
    echo -e "${BLUE}Running all tests...${NC}"
    bats "$TESTS_DIR/bats"
fi

# Show success message
echo ""
echo -e "${GREEN}All tests completed successfully!${NC}"
echo -e "${BLUE}=======================================${NC}"