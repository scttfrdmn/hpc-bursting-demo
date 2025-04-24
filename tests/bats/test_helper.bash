#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Helper functions for BATS tests

# Set up environment variables for testing
setup_test_environment() {
  # Find the project root directory
  export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  
  # Set up path to scripts
  export SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
  export AWS_SCRIPTS_DIR="${SCRIPTS_DIR}/aws"
  export LOCAL_SCRIPTS_DIR="${SCRIPTS_DIR}/local"

  # Create a temporary directory for test artifacts
  export BATS_TEST_TMPDIR="$(mktemp -d)"
  
  # Set AWS region for testing
  export AWS_REGION="us-west-2"
}

# Clean up after tests
teardown_test_environment() {
  # Remove temporary directory
  if [ -d "$BATS_TEST_TMPDIR" ]; then
    rm -rf "$BATS_TEST_TMPDIR"
  fi
}

# Mock AWS CLI commands
mock_aws_cli() {
  # Create mock aws-resources.txt file for testing
  cat > "${BATS_TEST_TMPDIR}/aws-resources.txt" <<EOF
# AWS Resources
AWS_REGION=us-west-2
VPC_ID=vpc-12345678
PUBLIC_SUBNET_ID=subnet-public12345
PRIVATE_SUBNET_ID=subnet-private12345
IGW_ID=igw-12345
PUBLIC_RTB_ID=rtb-public12345
PRIVATE_RTB_ID=rtb-private12345
BASTION_SG_ID=sg-bastion12345
COMPUTE_SG_ID=sg-compute12345
BASTION_ID=i-bastion12345
HOSTED_ZONE_ID=Z1234567890ABC
CPU_AMI_ID=ami-cpu12345
GPU_AMI_ID=ami-gpu12345
CPU_LAUNCH_TEMPLATE_ID=lt-cpu12345
GPU_LAUNCH_TEMPLATE_ID=lt-gpu12345
POLICY_ARN=arn:aws:iam::123456789012:policy/slurm-aws-plugin-policy
ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
EOF

  # Create a mock aws command that returns predictable output
  function aws() {
    local service="$1"
    local action="$2"
    shift 2
    
    case "$service $action" in
      "ec2 describe-instances")
        echo '{"Reservations": []}'
        ;;
      "ec2 describe-images")
        echo '{"Images": []}'
        ;;
      "ec2 describe-security-groups")
        echo '{"SecurityGroups": []}'
        ;;
      "ec2 describe-network-interfaces")
        echo '{"NetworkInterfaces": []}'
        ;;
      "ec2 terminate-instances")
        echo '{"TerminatingInstances": []}'
        ;;
      "ec2 delete-security-group")
        return 0
        ;;
      "ec2 delete-subnet")
        return 0
        ;;
      "ec2 delete-vpc")
        return 0
        ;;
      "iam delete-user")
        return 0
        ;;
      "logs describe-log-groups")
        echo '{"logGroups": []}'
        ;;
      "cloudformation list-stacks")
        echo '{"StackSummaries": []}'
        ;;
      "ce get-cost-and-usage")
        echo '{"ResultsByTime": [{"Groups": [], "TimePeriod": {"Start": "2025-01-01", "End": "2025-01-31"}, "Total": {"BlendedCost": {"Amount": "0.00", "Unit": "USD"}}}]}'
        ;;
      *)
        return 0
        ;;
    esac
  }
  
  export -f aws
}

# Utility to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Create a temporary log function for testing
log() {
  local level="$1"
  local message="$2"
  echo "[TEST] [$level] $message"
}
export -f log