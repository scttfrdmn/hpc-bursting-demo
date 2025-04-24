#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Create launch templates for compute nodes
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

# Load resource IDs
source ../aws-resources.txt

# For test mode, use mock resources
if [ "$TEST_MODE" = "true" ]; then
  echo "Test mode: Using mock launch templates"
  
  # Mock resource IDs
  CPU_LAUNCH_TEMPLATE_ID="lt-cpu-test12345"
  GPU_LAUNCH_TEMPLATE_ID="lt-gpu-test12345"
  INFERENTIA_LAUNCH_TEMPLATE_ID="lt-inf-test12345"
  TRAINIUM_LAUNCH_TEMPLATE_ID="lt-trn-test12345"
  
  # Update resources file and exit
  cat << RESOURCES >> ../aws-resources.txt
CPU_LAUNCH_TEMPLATE_ID=$CPU_LAUNCH_TEMPLATE_ID
GPU_LAUNCH_TEMPLATE_ID=$GPU_LAUNCH_TEMPLATE_ID
INFERENTIA_LAUNCH_TEMPLATE_ID=$INFERENTIA_LAUNCH_TEMPLATE_ID
TRAINIUM_LAUNCH_TEMPLATE_ID=$TRAINIUM_LAUNCH_TEMPLATE_ID
RESOURCES

  echo "Test mode: Mock launch templates created successfully."
  exit 0
fi

# Create launch template for CPU compute nodes
echo "Creating launch template for CPU compute nodes..."
CPU_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name hpc-demo-compute-cpu \
    --version-description "Initial version" \
    --launch-template-data "{
        \"ImageId\": \"$CPU_AMI_ID\",
        \"InstanceType\": \"${AMI_BUILDER_INSTANCE}\",
        \"KeyName\": \"hpc-demo-key\",
        \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
        \"TagSpecifications\": [
            {
                \"ResourceType\": \"instance\",
                \"Tags\": [
                    {
                        \"Key\": \"Name\",
                        \"Value\": \"hpc-demo-compute\"
                    },
                    {
                        \"Key\": \"Project\",
                        \"Value\": \"HPC-Bursting-Demo\"
                    }
                ]
            }
        ],
        \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
# This is handled by the slurm-node-startup service
exit 0')\"
    }" \
    --region $AWS_REGION \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text)

echo "Created CPU launch template: $CPU_LAUNCH_TEMPLATE_ID"

# Create launch template for GPU compute nodes
echo "Creating launch template for GPU compute nodes..."
GPU_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name hpc-demo-compute-gpu \
    --version-description "Initial version" \
    --launch-template-data "{
        \"ImageId\": \"$GPU_AMI_ID\",
        \"InstanceType\": \"${GPU_AMI_BUILDER_INSTANCE}\",
        \"KeyName\": \"hpc-demo-key\",
        \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
        \"TagSpecifications\": [
            {
                \"ResourceType\": \"instance\",
                \"Tags\": [
                    {
                        \"Key\": \"Name\",
                        \"Value\": \"hpc-demo-compute-gpu\"
                    },
                    {
                        \"Key\": \"Project\",
                        \"Value\": \"HPC-Bursting-Demo\"
                    }
                ]
            }
        ],
        \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
# This is handled by the slurm-node-startup service
exit 0')\"
    }" \
    --region $AWS_REGION \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text)

echo "Created GPU launch template: $GPU_LAUNCH_TEMPLATE_ID"

# Create launch templates for specialized instances if available
if [ "$INFERENTIA_AMI_ID" != "n/a" ]; then
    echo "Creating launch template for Inferentia compute nodes..."
    INFERENTIA_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
        --launch-template-name hpc-demo-compute-inferentia \
        --version-description "Initial version" \
        --launch-template-data "{
            \"ImageId\": \"$INFERENTIA_AMI_ID\",
            \"InstanceType\": \"${INFERENTIA_AMI_BUILDER_INSTANCE}\",
            \"KeyName\": \"hpc-demo-key\",
            \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
            \"TagSpecifications\": [
                {
                    \"ResourceType\": \"instance\",
                    \"Tags\": [
                        {
                            \"Key\": \"Name\",
                            \"Value\": \"hpc-demo-compute-inferentia\"
                        },
                        {
                            \"Key\": \"Project\",
                            \"Value\": \"HPC-Bursting-Demo\"
                        }
                    ]
                }
            ],
            \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
    # This is handled by the slurm-node-startup service
    exit 0')\"
        }" \
        --region $AWS_REGION \
        --query 'LaunchTemplate.LaunchTemplateId' \
        --output text)
    
    echo "Created Inferentia launch template: $INFERENTIA_LAUNCH_TEMPLATE_ID"
else
    INFERENTIA_LAUNCH_TEMPLATE_ID="n/a"
fi

if [ "$TRAINIUM_AMI_ID" != "n/a" ]; then
    echo "Creating launch template for Trainium compute nodes..."
    TRAINIUM_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
        --launch-template-name hpc-demo-compute-trainium \
        --version-description "Initial version" \
        --launch-template-data "{
            \"ImageId\": \"$TRAINIUM_AMI_ID\",
            \"InstanceType\": \"${TRAINIUM_AMI_BUILDER_INSTANCE}\",
            \"KeyName\": \"hpc-demo-key\",
            \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
            \"TagSpecifications\": [
                {
                    \"ResourceType\": \"instance\",
                    \"Tags\": [
                        {
                            \"Key\": \"Name\",
                            \"Value\": \"hpc-demo-compute-trainium\"
                        },
                        {
                            \"Key\": \"Project\",
                            \"Value\": \"HPC-Bursting-Demo\"
                        }
                    ]
                }
            ],
            \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
    # This is handled by the slurm-node-startup service
    exit 0')\"
        }" \
        --region $AWS_REGION \
        --query 'LaunchTemplate.LaunchTemplateId' \
        --output text)
    
    echo "Created Trainium launch template: $TRAINIUM_LAUNCH_TEMPLATE_ID"
else
    TRAINIUM_LAUNCH_TEMPLATE_ID="n/a"
fi

# Update aws-resources.txt
cat << RESOURCES >> ../aws-resources.txt
CPU_LAUNCH_TEMPLATE_ID=$CPU_LAUNCH_TEMPLATE_ID
GPU_LAUNCH_TEMPLATE_ID=$GPU_LAUNCH_TEMPLATE_ID
INFERENTIA_LAUNCH_TEMPLATE_ID=$INFERENTIA_LAUNCH_TEMPLATE_ID
TRAINIUM_LAUNCH_TEMPLATE_ID=$TRAINIUM_LAUNCH_TEMPLATE_ID
RESOURCES

echo "Launch template creation completed successfully."
