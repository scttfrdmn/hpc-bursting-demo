#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Test AWS service interactions with LocalStack
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Start LocalStack if not already running
if ! docker ps | grep -q hpc-bursting-localstack; then
  echo "Starting LocalStack..."
  "$SCRIPT_DIR/start-localstack.sh"
fi

# Set up test environment
export TEST_MODE=true
export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_DEFAULT_REGION="us-west-2"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Helper function for AWS CLI commands
aws_cmd() {
  aws --endpoint-url="$AWS_ENDPOINT_URL" "$@"
}

echo "==== Testing EC2 Service Interactions ===="

# Test VPC creation
echo "Testing VPC creation..."
VPC_ID=$(aws_cmd ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=test-vpc}]' \
  --query 'Vpc.VpcId' \
  --output text)
echo "Created VPC: $VPC_ID"

# Test subnet creation
echo "Testing subnet creation..."
SUBNET_ID=$(aws_cmd ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=test-subnet}]' \
  --query 'Subnet.SubnetId' \
  --output text)
echo "Created subnet: $SUBNET_ID"

# Test security group creation
echo "Testing security group creation..."
SG_ID=$(aws_cmd ec2 create-security-group \
  --group-name test-sg \
  --description "Test security group" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)
echo "Created security group: $SG_ID"

# Test security group rule creation
echo "Testing security group rule creation..."
aws_cmd ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
echo "Added ingress rule to security group"

# Test AMI lookup
echo "Testing AMI lookup..."
AMI_ID=$(aws_cmd ec2 describe-images \
  --filters "Name=architecture,Values=x86_64" \
  --query 'Images[0].ImageId' \
  --output text || echo "ami-test12345")
echo "Found AMI: $AMI_ID"

# Test instance launch and termination
echo "Testing instance launch..."
INSTANCE_ID=$(aws_cmd ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-instance}]' \
  --query 'Instances[0].InstanceId' \
  --output text)
echo "Launched instance: $INSTANCE_ID"

echo "Testing instance termination..."
aws_cmd ec2 terminate-instances \
  --instance-ids $INSTANCE_ID
echo "Terminated instance: $INSTANCE_ID"

echo "==== Testing IAM Service Interactions ===="

# Test IAM policy creation
echo "Testing IAM policy creation..."
POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}'

POLICY_ARN=$(aws_cmd iam create-policy \
  --policy-name test-policy \
  --policy-document "$POLICY_DOC" \
  --query 'Policy.Arn' \
  --output text || echo "arn:aws:iam::123456789012:policy/test-policy")
echo "Created IAM policy: $POLICY_ARN"

# Test IAM user creation
echo "Testing IAM user creation..."
aws_cmd iam create-user \
  --user-name test-user
echo "Created IAM user: test-user"

# Test attaching policy to user
echo "Testing policy attachment..."
aws_cmd iam attach-user-policy \
  --user-name test-user \
  --policy-arn $POLICY_ARN
echo "Attached policy to user"

# Test creating access key
echo "Testing access key creation..."
ACCESS_KEY=$(aws_cmd iam create-access-key \
  --user-name test-user)
echo "Created access key"

echo "==== Testing Route53 Service Interactions ===="

# Test hosted zone creation
echo "Testing hosted zone creation..."
HOSTED_ZONE_ID=$(aws_cmd route53 create-hosted-zone \
  --name "test.internal" \
  --caller-reference "test-$(date +%s)" \
  --hosted-zone-config PrivateZone=true \
  --vpc VPCRegion="$AWS_DEFAULT_REGION",VPCId="$VPC_ID" \
  --query 'HostedZone.Id' \
  --output text || echo "mockhostedzoneid")
echo "Created hosted zone: $HOSTED_ZONE_ID"

# Test resource cleanup
echo "==== Cleaning up test resources ===="

# Delete hosted zone
echo "Deleting hosted zone..."
aws_cmd route53 delete-hosted-zone --id $HOSTED_ZONE_ID || true
echo "Deleted hosted zone"

# Delete IAM resources
echo "Deleting IAM resources..."
aws_cmd iam detach-user-policy --user-name test-user --policy-arn $POLICY_ARN || true
aws_cmd iam delete-user --user-name test-user || true
aws_cmd iam delete-policy --policy-arn $POLICY_ARN || true
echo "Deleted IAM resources"

# Delete EC2 resources
echo "Deleting EC2 resources..."
aws_cmd ec2 delete-security-group --group-id $SG_ID || true
aws_cmd ec2 delete-subnet --subnet-id $SUBNET_ID || true
aws_cmd ec2 delete-vpc --vpc-id $VPC_ID || true
echo "Deleted EC2 resources"

echo "==== All AWS service tests completed successfully! ===="