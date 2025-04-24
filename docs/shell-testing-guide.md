# Shell Script Testing Guide

This guide provides best practices and examples for writing effective tests for shell scripts in the HPC Bursting Demo project.

> **Note**: All tests developed for this project are located in the `/tests/bats` directory and are run using the BATS framework.

## Overview

Shell script testing uses BATS (Bash Automated Testing System) to:
1. Verify script functionality and correctness
2. Catch regressions when changes are made
3. Document expected script behavior
4. Ensure consistent error handling

## Key Testing Principles

### 1. Test Units of Functionality

Break down shell scripts into testable units:

```bash
# Original function
function cleanup_resources() {
  # Delete instances
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  
  # Delete security groups
  aws ec2 delete-security-group --group-id $SG_ID
}

# More testable version
function delete_instances() {
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  return $?
}

function delete_security_groups() {
  aws ec2 delete-security-group --group-id $SG_ID
  return $?
}

function cleanup_resources() {
  delete_instances
  delete_security_groups
}
```

### 2. Mock External Dependencies

Always mock AWS CLI commands and other external tools:

```bash
# In test_helper.bash
function aws() {
  case "$1 $2" in
    "ec2 describe-instances")
      echo '{"Reservations": []}'
      ;;
    *)
      return 0
      ;;
  esac
}
export -f aws
```

### 3. Test Arguments and Options

Ensure all command line arguments and options are tested:

```bash
@test "Script handles --force option correctly" {
  run bash /path/to/script.sh --force
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Force mode enabled"* ]]
}
```

### 4. Test Error Handling

Validate that scripts handle errors appropriately:

```bash
@test "Script exits with error on invalid input" {
  run bash /path/to/script.sh --invalid-option
  
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid option"* ]]
}
```

### 5. Setup and Teardown

Use setup and teardown functions to prepare and clean the test environment:

```bash
setup() {
  # Create temporary directory
  export TEMP_DIR=$(mktemp -d)
  
  # Mock AWS credentials
  export AWS_ACCESS_KEY_ID="test"
  export AWS_SECRET_ACCESS_KEY="test"
}

teardown() {
  # Remove temporary directory
  rm -rf "$TEMP_DIR"
  
  # Unset environment variables
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
}
```

## Recommended Test Structure

Each test file should follow this structure:

1. **Setup/Teardown**: Prepare and clean the environment
2. **Command-line Arguments**: Test option parsing
3. **Core Functionality**: Test the main functions
4. **Error Handling**: Test error scenarios
5. **Integration**: Test interactions between components

## Example BATS Test

Here's an example from our project, testing the AWS resource cleanup script:

```bash
#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Tests for AWS resources cleanup script

# Load test helpers
load test_helper

# Set up test environment before each test
setup() {
  setup_test_environment
  mock_aws_cli
  
  # Create a modified version of the script without command line parsing
  TEMP_SCRIPT="$BATS_TEST_TMPDIR/cleanup_aws_resources_modified.sh"
  sed '/^while \[\[ $# -gt 0 \]\]; do/,/^done/d' "$AWS_SCRIPTS_DIR/cleanup_aws_resources.sh" > "$TEMP_SCRIPT"
}

# Clean up after each test
teardown() {
  teardown_test_environment
}

# Test command line argument parsing
@test "Cleanup script parses --force flag correctly" {
  # Create a small test script to check flag parsing
  cat > "$BATS_TEST_TMPDIR/test_force.sh" << 'EOF'
  #!/bin/bash
  FORCE=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --force)
        FORCE=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  echo "$FORCE"
EOF
  chmod +x "$BATS_TEST_TMPDIR/test_force.sh"
  
  # Run the test script with --force flag
  run "$BATS_TEST_TMPDIR/test_force.sh" --force
  
  # Check that FORCE is set to true
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# Test resource cleanup functionality
@test "Cleanup script attempts to delete CloudFormation stack if it exists" {
  # Create a test script for CloudFormation stack deletion
  cat > "$BATS_TEST_TMPDIR/test_cloudformation.sh" << 'EOF'
  #!/bin/bash
  log() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
  }

  function aws() {
    if [[ "$1 $2" == "cloudformation list-stacks" ]]; then
      echo '{"StackSummaries": [{"StackName": "hpc-bursting-stack", "StackStatus": "CREATE_COMPLETE"}]}'
      return 0
    fi
    return 0
  }
  
  log "INFO" "Checking for CloudFormation stack..."
  STACK_EXISTS=$(aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query "StackSummaries[?contains(StackName,'hpc-bursting')].StackName" \
    --output text)

  if [ ! -z "$STACK_EXISTS" ]; then
    log "INFO" "Found CloudFormation stack: $STACK_EXISTS"
    log "INFO" "Deleting CloudFormation stack..."
  fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/test_cloudformation.sh"
  
  # Run test script
  run "$BATS_TEST_TMPDIR/test_cloudformation.sh"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleting CloudFormation stack"* ]]
}
```

## Key Patterns in Our Tests

Our tests have demonstrated several effective patterns:

1. **Isolated Test Scripts**: Instead of running the actual scripts, we create small test scripts that test a specific behavior.

2. **Mocking AWS CLI**: We mock the AWS CLI to avoid making real API calls and to control the responses.

3. **Testing Specific File Operations**: For operations that modify files, we use temporary directories and files to avoid affecting the real system.

4. **Validating Output Patterns**: We check that command output contains specific strings to verify correct behavior.

5. **Breaking Down Complex Scripts**: For complex scripts with many steps, we test each step individually.

6. **Separating Command Line Parsing**: We test command-line parsing separately from other functionality to make tests more focused.

## Common Testing Patterns

### 1. Testing Functions in a Script

To test individual functions, source the script first:

```bash
@test "Function processes data correctly" {
  source "$SCRIPTS_DIR/script_with_functions.sh"
  
  result=$(process_data "test-input")
  
  [ "$result" = "expected-output" ]
}
```

### 2. Testing Environment Variables

Check that scripts properly use environment variables:

```bash
@test "Script uses AWS_REGION environment variable" {
  export AWS_REGION="us-east-1"
  
  run bash "$SCRIPTS_DIR/region_aware_script.sh"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Using region: us-east-1"* ]]
}
```

### 3. Testing File Operations

Use temporary directories to test file operations:

```bash
@test "Script creates output file" {
  run bash "$SCRIPTS_DIR/file_creator.sh" --output "$BATS_TEST_TMPDIR/output.txt"
  
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/output.txt" ]
  [[ "$(cat "$BATS_TEST_TMPDIR/output.txt")" == "expected content" ]]
}
```

## Resources

- [BATS Documentation](https://github.com/bats-core/bats-core)
- [BATS Assertions](https://github.com/bats-core/bats-assert)
- [BATS Files](https://github.com/bats-core/bats-file)
- [Shell Script Testing Best Practices](https://google.github.io/styleguide/shellguide.html)