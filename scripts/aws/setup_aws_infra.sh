#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Main script for AWS infrastructure setup
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Default options
USE_QUICK_MODE=false
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
    --quick)
      USE_QUICK_MODE=true
      shift
      ;;
    --test-mode)
      TEST_MODE=true
      USE_QUICK_MODE=true  # Test mode defaults to quick mode
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --quick      Use quick mode (smaller instances, CPU-only AMIs)"
      echo "  --test-mode  Run in test mode using LocalStack for AWS service emulation"
      echo "  --help       Show this help message"
      echo ""
      echo "Example:"
      echo "  $0              Full deployment with all features"
      echo "  $0 --quick      Quick setup with minimal cost for testing"
      echo "  $0 --test-mode  Run using LocalStack for testing without creating real AWS resources"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# Log function
log() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

MODE_MSG=$([ "$USE_QUICK_MODE" == "true" ] && echo "quick mode" || echo "standard mode")
log "INFO" "Starting AWS infrastructure setup (${MODE_MSG})..."

# Prepare options to pass to subscripts
TEST_MODE_OPT=""
QUICK_MODE_OPT=""

if [ "$TEST_MODE" == "true" ]; then
  TEST_MODE_OPT="--test-mode"
  export TEST_MODE=true
  export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
fi

if [ "$USE_QUICK_MODE" == "true" ]; then
  QUICK_MODE_OPT="--quick"
fi

# Step 1: Create IAM user and policy
log "INFO" "Creating IAM user and policy..."
./01_create_iam_user.sh $TEST_MODE_OPT
if [ $? -ne 0 ]; then
  log "ERROR" "IAM user creation failed. Exiting."
  exit 1
fi

# Step 2: Set up VPC and networking
log "INFO" "Setting up VPC and networking..."
./02_setup_vpc.sh $TEST_MODE_OPT
if [ $? -ne 0 ]; then
  log "ERROR" "VPC setup failed. Exiting."
  exit 1
fi

# Step 3: Launch bastion and set up WireGuard
log "INFO" "Launching bastion and setting up WireGuard..."
./03_setup_bastion.sh $TEST_MODE_OPT
if [ $? -ne 0 ]; then
  log "ERROR" "Bastion setup failed. Exiting."
  exit 1
fi

# Step 4: Create AMIs for compute nodes
log "INFO" "Creating AMIs for compute nodes..."
if [ "$USE_QUICK_MODE" == "true" ]; then
  log "INFO" "Using quick mode for AMI creation (CPU-only, t-series instances)..."
  ./04_create_amis.sh $QUICK_MODE_OPT $TEST_MODE_OPT
else
  ./04_create_amis.sh $TEST_MODE_OPT
fi
if [ $? -ne 0 ]; then
  log "ERROR" "AMI creation failed. Exiting."
  exit 1
fi

# Step 5: Create launch template
log "INFO" "Creating launch template..."
./05_create_launch_template.sh $TEST_MODE_OPT
if [ $? -ne 0 ]; then
  log "ERROR" "Launch template creation failed. Exiting."
  exit 1
fi

# Step 6: Configure Slurm AWS Plugin
log "INFO" "Configuring Slurm AWS Plugin..."
./06_configure_slurm_aws_plugin.sh $TEST_MODE_OPT
if [ $? -ne 0 ]; then
  log "ERROR" "Slurm AWS Plugin configuration failed. Exiting."
  exit 1
fi

# Setup complete
log "INFO" "AWS infrastructure setup completed successfully."
log "INFO" "You can now run the test script to verify the setup."
