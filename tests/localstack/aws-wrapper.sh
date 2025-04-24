#!/bin/bash
#
# AWS CLI wrapper for testing with LocalStack
# This script wraps the AWS CLI to use LocalStack when in test mode

# Default to real AWS
AWS_CLI_CMD="aws"
AWS_CLI_ARGS=()

# Check if we're in test mode
if [ "${TEST_MODE:-false}" = "true" ]; then
  # Use LocalStack endpoint
  ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
  AWS_CLI_ARGS+=("--endpoint-url=$ENDPOINT_URL")
  
  # Set test credentials
  export AWS_ACCESS_KEY_ID="test"
  export AWS_SECRET_ACCESS_KEY="test"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}"
  
  echo "Running in TEST MODE using LocalStack at $ENDPOINT_URL"
fi

# Pass all arguments to the AWS CLI
"$AWS_CLI_CMD" "${AWS_CLI_ARGS[@]}" "$@"