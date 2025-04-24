#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Create IAM user and policy for Slurm AWS Plugin
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

# Create a policy file for Slurm AWS Plugin
echo "Creating IAM policy for Slurm AWS Plugin..."
cat << 'POLICY' > slurm-aws-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:CreateTags",
        "ec2:DescribeTags",
        "ec2:DescribeImages",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": "*"
    }
  ]
}
POLICY

# Set AWS region
AWS_REGION=${AWS_REGION:-"us-west-2"}

# Create the IAM policy
echo "Creating IAM policy..."
if [ "$TEST_MODE" = "true" ]; then
  # Use mock policy ARN in test mode
  POLICY_ARN="arn:aws:iam::123456789012:policy/slurm-aws-plugin-policy-mock"
  echo "Test mode: Using mock policy ARN"
else
  POLICY_ARN=$(aws_cmd iam create-policy \
      --policy-name slurm-aws-plugin-policy \
      --policy-document file://slurm-aws-policy.json \
      --query 'Policy.Arn' --output text)
fi

echo "Created policy: $POLICY_ARN"

# Create IAM user for Slurm AWS Plugin
echo "Creating IAM user..."
aws_cmd iam create-user --user-name slurm-aws-plugin

# Attach policy to user
echo "Attaching policy to user..."
aws_cmd iam attach-user-policy \
    --user-name slurm-aws-plugin \
    --policy-arn $POLICY_ARN

# Create access key for the user
echo "Creating access key..."
if [ "$TEST_MODE" = "true" ]; then
  # Create mock credentials in test mode
  cat << MOCKCREDS > slurm-aws-credentials.json
{
  "AccessKey": {
    "UserName": "slurm-aws-plugin",
    "AccessKeyId": "AKIATESTMOCK12345678",
    "Status": "Active",
    "SecretAccessKey": "testsecretkeymock1234567890abcdefghijk",
    "CreateDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  }
}
MOCKCREDS
else
  aws_cmd iam create-access-key \
      --user-name slurm-aws-plugin > slurm-aws-credentials.json
fi

# Extract and save credentials
ACCESS_KEY_ID=$(cat slurm-aws-credentials.json | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(cat slurm-aws-credentials.json | jq -r '.AccessKey.SecretAccessKey')

# Save to aws-resources.txt for other scripts to use
echo "Saving resource IDs..."
cat << RESOURCES > ../aws-resources.txt
AWS_REGION=$AWS_REGION
POLICY_ARN=$POLICY_ARN
ACCESS_KEY_ID=$ACCESS_KEY_ID
SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY
RESOURCES

echo "IAM user and policy created successfully."
