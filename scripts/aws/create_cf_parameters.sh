#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Create CloudFormation parameters file from AMI IDs in aws-resources.txt
set -e

# Default options
TEST_MODE=false

# Check if running in test mode with LocalStack
if [ "${TEST_MODE:-false}" = "true" ]; then
  # Set AWS endpoint URL for LocalStack
  AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
  echo "Running in TEST MODE using LocalStack at $AWS_ENDPOINT_URL"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --test-mode)
      TEST_MODE=true
      export TEST_MODE=true
      export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
      echo "Running in TEST MODE using LocalStack at $AWS_ENDPOINT_URL"
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --test-mode  Run in test mode using LocalStack for AWS service emulation"
      echo "  --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# Helper function for AWS CLI commands with optional LocalStack endpoint
aws_cmd() {
  if [ "$TEST_MODE" = "true" ]; then
    aws --endpoint-url="$AWS_ENDPOINT_URL" "$@"
  else
    aws "$@"
  fi
}

# Check for aws-resources.txt
if [ ! -f "../aws-resources.txt" ]; then
  echo "Error: aws-resources.txt not found"
  exit 1
fi

# Source the resource file
source ../aws-resources.txt

# Create directory if it doesn't exist
mkdir -p ../cloudformation

# Determine which AMIs to include based on architecture
if [ "$ARCH" == "arm64" ]; then
  # ARM64 architecture
  cat << PARAMJSON > ../cloudformation/ami-parameters.json
[
  {
    "ParameterKey": "ARM64CPUAMI",
    "ParameterValue": "$CPU_AMI_ID"
  },
  {
    "ParameterKey": "ARM64GPUAMI",
    "ParameterValue": "$GPU_AMI_ID"
  },
  {
    "ParameterKey": "X86CPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "X86GPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "Architecture",
    "ParameterValue": "arm64"
  }
]
PARAMJSON
else
  # X86_64 architecture
  cat << PARAMJSON > ../cloudformation/ami-parameters.json
[
  {
    "ParameterKey": "X86CPUAMI",
    "ParameterValue": "$CPU_AMI_ID"
  },
  {
    "ParameterKey": "X86GPUAMI",
    "ParameterValue": "$GPU_AMI_ID"
  },
  {
    "ParameterKey": "ARM64CPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "ARM64GPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "Architecture",
    "ParameterValue": "x86_64"
  }
]
PARAMJSON
fi

echo "CloudFormation parameters file created: ../cloudformation/ami-parameters.json"
