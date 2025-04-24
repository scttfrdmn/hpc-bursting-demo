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
  # Source the script to test internal functions
  source "$AWS_SCRIPTS_DIR/cleanup_aws_resources.sh" || true
}

# Clean up after each test
teardown() {
  teardown_test_environment
}

# Test command line argument parsing
@test "Cleanup script parses --force flag correctly" {
  # Mock required functions
  function aws() { return 0; }
  export -f aws
  
  # Capture the FORCE variable value
  run bash -c "source $AWS_SCRIPTS_DIR/cleanup_aws_resources.sh --force && echo \$FORCE"
  
  # Check that FORCE is set to true
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "Cleanup script shows help message with --help" {
  run bash "$AWS_SCRIPTS_DIR/cleanup_aws_resources.sh" --help
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--force"* ]]
  [[ "$output" == *"--help"* ]]
}

# Test resource identification functionality
@test "Cleanup script can load resources from aws-resources.txt" {
  # Create mock aws-resources.txt in the expected location
  mkdir -p "$BATS_TEST_TMPDIR/scripts"
  cp "$BATS_TEST_TMPDIR/aws-resources.txt" "$BATS_TEST_TMPDIR/scripts/aws-resources.txt"
  
  # Run script with redirection to load the resources file
  BASH_ENV="$BATS_TEST_TMPDIR/aws-resources.txt" run bash -c "source $AWS_SCRIPTS_DIR/cleanup_aws_resources.sh && echo \$VPC_ID"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"vpc-12345678"* ]]
}

# Test resource cleanup functionality
@test "Cleanup script attempts to delete CloudFormation stack if it exists" {
  # Mock the aws cloudformation list-stacks command to return a stack
  function aws() {
    if [[ "$1 $2" == "cloudformation list-stacks" ]]; then
      echo '{"StackSummaries": [{"StackName": "hpc-bursting-stack", "StackStatus": "CREATE_COMPLETE"}]}'
      return 0
    fi
    return 0
  }
  export -f aws
  
  # Capture the log output to check if stack deletion is attempted
  run bash -c "source $AWS_SCRIPTS_DIR/cleanup_aws_resources.sh --force && echo 'Done'"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleting CloudFormation stack"* ]]
}

@test "Cleanup script handles missing aws-resources.txt file" {
  # Ensure aws-resources.txt doesn't exist
  rm -f "$BATS_TEST_TMPDIR/aws-resources.txt" 2>/dev/null
  
  # Run script without the resources file
  run bash -c "cd $BATS_TEST_TMPDIR && source $AWS_SCRIPTS_DIR/cleanup_aws_resources.sh --force && echo 'Done'"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"aws-resources.txt not found"* ]]
  [[ "$output" == *"Done"* ]]
}

@test "Cleanup script attempts to clean up ENIs" {
  # Mock aws ec2 describe-network-interfaces to return ENIs
  function aws() {
    if [[ "$1 $2" == "ec2 describe-network-interfaces" ]]; then
      echo '{"NetworkInterfaces": [{"NetworkInterfaceId": "eni-12345678", "Attachment": {"Status": "attached", "AttachmentId": "attach-12345"}}]}'
      return 0
    fi
    return 0
  }
  export -f aws
  
  # Run the script and check if ENI cleanup is attempted
  run bash -c "source $AWS_SCRIPTS_DIR/cleanup_aws_resources.sh --force && echo 'Done'"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found elastic network interface"* ]]
  [[ "$output" == *"Deleting network interface"* ]]
}

@test "Cleanup script handles CloudWatch log groups" {
  # Mock aws logs describe-log-groups to return log groups
  function aws() {
    if [[ "$1 $2" == "logs describe-log-groups" ]]; then
      echo '{"logGroups": [{"logGroupName": "/aws/ec2/hpc-demo-log"}]}'
      return 0
    fi
    return 0
  }
  export -f aws
  
  # Run the script and check if log group cleanup is attempted
  run bash -c "source $AWS_SCRIPTS_DIR/cleanup_aws_resources.sh --force && echo 'Done'"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleting log group"* ]]
}