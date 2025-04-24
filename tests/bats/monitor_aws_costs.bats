#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Tests for AWS costs monitoring script

# Load test helpers
load test_helper

# Set up test environment before each test
setup() {
  setup_test_environment
  mock_aws_cli
}

# Clean up after each test
teardown() {
  teardown_test_environment
}

# Test command line argument parsing
@test "Monitor script parses --costs-only flag correctly" {
  # Run the script with --costs-only flag
  run bash -c "export CHECK_RESOURCES=true; source $SCRIPTS_DIR/monitor-aws-costs.sh --costs-only && echo \$CHECK_RESOURCES"
  
  # Check that CHECK_RESOURCES is set to false
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "Monitor script shows help message with --help" {
  run bash "$SCRIPTS_DIR/monitor-aws-costs.sh" --help
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--costs-only"* ]]
  [[ "$output" == *"--help"* ]]
}

# Test cross-platform date handling
@test "Monitor script handles date calculations for different platforms" {
  # Source the script to access functions
  source "$SCRIPTS_DIR/monitor-aws-costs.sh" || true
  
  # Run the get_date_range function
  run bash -c "source $SCRIPTS_DIR/monitor-aws-costs.sh && get_date_range"
  
  # Check that the function returns date strings
  [ "$status" -eq 0 ]
  # Should have a start and end date string
  [[ "$output" == *"-"* ]]
  # Should have two dates separated by space
  [[ $(echo "$output" | wc -w) -eq 2 ]]
}

# Test AWS API calls
@test "Monitor script makes correct EC2 usage API calls" {
  # Create a test function to capture AWS calls
  function aws() {
    if [[ "$1 $2" == "ce get-cost-and-usage" && "$*" == *"ec2"* ]]; then
      echo "EC2_USAGE_CALL_MADE"
      echo '{"ResultsByTime": [{"Groups": [], "Total": {"BlendedCost": {"Amount": "0.00", "Unit": "USD"}}}]}'
    else
      echo '{"ResultsByTime": []}'
    fi
  }
  export -f aws
  
  # Run the script and check if EC2 usage call is made
  run bash -c "source $SCRIPTS_DIR/monitor-aws-costs.sh --costs-only"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"EC2_USAGE_CALL_MADE"* ]]
}

# Test reporting functionality
@test "Monitor script creates a report file with appropriate sections" {
  # Mock AWS responses
  function aws() {
    if [[ "$1 $2" == "ce get-cost-and-usage" ]]; then
      echo '{"ResultsByTime": [{"Groups": [{"Keys": ["Amazon Elastic Compute Cloud"], "Metrics": {"BlendedCost": {"Amount": "1.23", "Unit": "USD"}}}], "Total": {"BlendedCost": {"Amount": "1.23", "Unit": "USD"}}}]}'
    elif [[ "$1 $2" == "ec2 describe-instances" ]]; then
      echo '{"Reservations": []}'
    else
      echo '{}'
    fi
  }
  export -f aws
  
  # Run the script
  run bash -c "cd $BATS_TEST_TMPDIR && source $SCRIPTS_DIR/monitor-aws-costs.sh --costs-only"
  
  # Verify output sections
  [ "$status" -eq 0 ]
  [[ "$output" == *"EC2 INSTANCE USAGE BY TYPE"* ]]
  [[ "$output" == *"TOTAL AWS SERVICES COST"* ]]
  [[ "$output" == *"HPC BURSTING PROJECT COST"* ]]
  [[ "$output" == *"Amazon Elastic Compute Cloud: $1.23"* ]]
}

# Test active resources check
@test "Monitor script checks for active AWS resources" {
  # Mock AWS responses
  function aws() {
    if [[ "$1 $2" == "ec2 describe-instances" ]]; then
      echo '{"Reservations": [{"Instances": [{"InstanceId": "i-12345678", "InstanceType": "t3.micro", "State": {"Name": "running"}, "LaunchTime": "2025-01-01T00:00:00Z"}]}]}'
    elif [[ "$1 $2" == "ec2 describe-images" ]]; then
      echo '{"Images": [{"ImageId": "ami-12345678", "Name": "hpc-demo-compute-cpu", "CreationDate": "2025-01-01T00:00:00Z"}]}'
    elif [[ "$1 $2" == "ec2 describe-launch-templates" ]]; then
      echo '{"LaunchTemplates": [{"LaunchTemplateId": "lt-12345678", "LaunchTemplateName": "hpc-demo-compute-cpu", "CreateTime": "2025-01-01T00:00:00Z"}]}'
    else
      echo '{}'
    fi
  }
  export -f aws
  
  # Run the script
  run bash -c "cd $BATS_TEST_TMPDIR && source $SCRIPTS_DIR/monitor-aws-costs.sh"
  
  # Verify output sections
  [ "$status" -eq 0 ]
  [[ "$output" == *"ACTIVE HPC DEMO RESOURCES"* ]]
  [[ "$output" == *"EC2 INSTANCES"* ]]
  [[ "$output" == *"i-12345678"* ]]
  [[ "$output" == *"CUSTOM AMIS"* ]]
  [[ "$output" == *"ami-12345678"* ]]
  [[ "$output" == *"LAUNCH TEMPLATES"* ]]
  [[ "$output" == *"lt-12345678"* ]]
}