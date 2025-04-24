# Shell Script Testing Guide

This guide provides best practices and examples for writing effective tests for shell scripts in the HPC Bursting Demo project.

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

```bash
#!/usr/bin/env bats

# Load test helpers and libraries
load test_helper

# Setup test environment
setup() {
  setup_test_environment
  mock_aws_cli
}

# Clean up after test
teardown() {
  teardown_test_environment
}

# Test help functionality
@test "Script displays help message" {
  run bash "$SCRIPTS_DIR/example.sh" --help
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# Test normal functionality
@test "Script performs main function correctly" {
  # Mock specific AWS responses for this test
  function aws() {
    if [[ "$1 $2" == "ec2 describe-instances" ]]; then
      echo '{"Reservations": [{"Instances": [{"InstanceId": "i-12345"}]}]}'
    fi
    return 0
  }
  export -f aws
  
  run bash "$SCRIPTS_DIR/example.sh"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found instance: i-12345"* ]]
}

# Test error handling
@test "Script handles AWS errors gracefully" {
  # Make AWS command fail
  function aws() {
    return 1
  }
  export -f aws
  
  run bash "$SCRIPTS_DIR/example.sh"
  
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to query AWS"* ]]
}
```

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