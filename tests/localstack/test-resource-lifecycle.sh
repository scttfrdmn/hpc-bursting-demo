#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Test the full AWS resource lifecycle using LocalStack
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Start LocalStack if not already running
if ! docker ps | grep -q hpc-bursting-localstack; then
  echo "Starting LocalStack..."
  "$SCRIPT_DIR/start-localstack.sh"
fi

# Set up test environment
export TEST_MODE=true
export AWS_ENDPOINT_URL="http://localhost:4566"
export PATH="$SCRIPT_DIR:$PATH"  # Add aws-wrapper.sh to PATH

# Function to run a command and check its exit status
run_test() {
  local cmd="$1"
  local description="$2"
  
  echo "------------------------------------------------------"
  echo "Testing: $description"
  echo "Command: $cmd"
  echo "------------------------------------------------------"
  
  if eval "$cmd"; then
    echo "✅ PASSED: $description"
    return 0
  else
    echo "❌ FAILED: $description"
    return 1
  fi
}

# Change to the AWS scripts directory
cd "$REPO_ROOT/scripts/aws"

# Make sure we're starting with a clean slate
run_test "./cleanup_aws_resources.sh --force --test-mode" "Initial cleanup"

# Test the full creation flow
run_test "./setup_aws_infra.sh --test-mode" "Full infrastructure setup in test mode"

# Verify resource files were created
if [ -f "../aws-resources.txt" ]; then
  echo "✅ Resource file created successfully"
  echo "Resources:"
  grep -v "SECRET" ../aws-resources.txt
else
  echo "❌ Resource file not created"
  exit 1
fi

# Test CloudFormation parameters creation
run_test "./create_cf_parameters.sh --test-mode" "Create CloudFormation parameters"

# Test resource cleanup
run_test "./cleanup_aws_resources.sh --force --test-mode" "Resource cleanup"

echo ""
echo "------------------------------------------------------"
echo "All lifecycle tests completed successfully!"
echo "------------------------------------------------------"