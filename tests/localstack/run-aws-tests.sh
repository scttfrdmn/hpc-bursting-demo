#!/bin/bash
#
# Run AWS tests using LocalStack
# This script demonstrates how to run tests against the LocalStack environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Start LocalStack if it's not already running
if ! docker ps | grep -q hpc-bursting-localstack; then
  echo "Starting LocalStack environment..."
  "$SCRIPT_DIR/start-localstack.sh"
fi

# Set environment variables for testing
export TEST_MODE="true"
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-west-2"
export PATH="$SCRIPT_DIR:$PATH"  # Add aws-wrapper.sh to PATH

# Run a sample test to verify LocalStack is working
echo "Testing LocalStack setup with simple AWS CLI commands..."
echo

echo "Listing VPCs:"
aws-wrapper.sh ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value]' --output table
echo

echo "Listing AMIs:"
aws-wrapper.sh ec2 describe-images --owners self --query 'Images[*].[ImageId,Name]' --output table
echo

# Example of how to run a script with test mode
echo "Running a test with the AWS script in test mode..."
# Uncomment and modify the line below to test an actual script
# TEST_MODE=true AWS_ENDPOINT_URL="http://localhost:4566" "$REPO_ROOT/scripts/aws/04_create_amis.sh" --test-mode

echo
echo "All tests completed!"
echo "LocalStack is still running. To stop it, run: docker-compose -f $SCRIPT_DIR/docker-compose.yml down"