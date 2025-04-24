#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Initialize LocalStack with required AWS resources for testing

set -e

echo "Initializing LocalStack with required AWS resources..."

# Configure AWS CLI to use LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-west-2
export ENDPOINT_URL="http://localhost:4566"

# Helper function for AWS CLI commands using LocalStack endpoint
aws_local() {
  aws --endpoint-url=$ENDPOINT_URL "$@"
}

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws_local ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=hpc-demo-vpc},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'Vpc.VpcId' \
  --output text)
echo "Created VPC: $VPC_ID"

# Create subnets
echo "Creating public subnet..."
PUBLIC_SUBNET_ID=$(aws_local ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=hpc-demo-public-subnet},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'Subnet.SubnetId' \
  --output text)
echo "Created public subnet: $PUBLIC_SUBNET_ID"

echo "Creating private subnet..."
PRIVATE_SUBNET_ID=$(aws_local ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=hpc-demo-private-subnet},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'Subnet.SubnetId' \
  --output text)
echo "Created private subnet: $PRIVATE_SUBNET_ID"

# Create internet gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws_local ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=hpc-demo-igw},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
echo "Created Internet Gateway: $IGW_ID"

# Attach internet gateway to VPC
echo "Attaching Internet Gateway to VPC..."
aws_local ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

# Create route tables
echo "Creating public route table..."
PUBLIC_RTB_ID=$(aws_local ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=hpc-demo-public-rtb},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo "Created public route table: $PUBLIC_RTB_ID"

echo "Creating private route table..."
PRIVATE_RTB_ID=$(aws_local ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=hpc-demo-private-rtb},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)
echo "Created private route table: $PRIVATE_RTB_ID"

# Create routes
echo "Creating route to Internet Gateway..."
aws_local ec2 create-route \
  --route-table-id $PUBLIC_RTB_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate route tables with subnets
echo "Associating public route table with public subnet..."
aws_local ec2 associate-route-table \
  --route-table-id $PUBLIC_RTB_ID \
  --subnet-id $PUBLIC_SUBNET_ID

echo "Associating private route table with private subnet..."
aws_local ec2 associate-route-table \
  --route-table-id $PRIVATE_RTB_ID \
  --subnet-id $PRIVATE_SUBNET_ID

# Create security groups
echo "Creating bastion security group..."
BASTION_SG_ID=$(aws_local ec2 create-security-group \
  --group-name hpc-demo-bastion-sg \
  --description "Security group for HPC bursting bastion host" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=hpc-demo-bastion-sg},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'GroupId' \
  --output text)
echo "Created bastion security group: $BASTION_SG_ID"

echo "Creating compute security group..."
COMPUTE_SG_ID=$(aws_local ec2 create-security-group \
  --group-name hpc-demo-compute-sg \
  --description "Security group for HPC bursting compute nodes" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=hpc-demo-compute-sg},{Key=Project,Value=HPC-Bursting-Demo}]' \
  --query 'GroupId' \
  --output text)
echo "Created compute security group: $COMPUTE_SG_ID"

# Configure security group rules
echo "Configuring security group rules..."
aws_local ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws_local ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG_ID \
  --protocol udp \
  --port 51820 \
  --cidr 0.0.0.0/0

aws_local ec2 authorize-security-group-ingress \
  --group-id $COMPUTE_SG_ID \
  --protocol -1 \
  --source-group $COMPUTE_SG_ID

aws_local ec2 authorize-security-group-ingress \
  --group-id $COMPUTE_SG_ID \
  --protocol -1 \
  --source-group $BASTION_SG_ID

# Create IAM user for Slurm AWS Plugin
echo "Creating IAM user for Slurm AWS Plugin..."
aws_local iam create-user \
  --user-name slurm-aws-plugin

# Create IAM policy
echo "Creating IAM policy for Slurm AWS Plugin..."
POLICY_ARN=$(aws_local iam create-policy \
  --policy-name slurm-aws-plugin-policy \
  --policy-document '{
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
  }' \
  --query 'Policy.Arn' \
  --output text)
echo "Created IAM policy: $POLICY_ARN"

# Attach policy to user
echo "Attaching IAM policy to user..."
aws_local iam attach-user-policy \
  --user-name slurm-aws-plugin \
  --policy-arn $POLICY_ARN

# Create dummy AMIs
echo "Creating dummy AMIs..."
CPU_AMI_ID=$(aws_local ec2 register-image \
  --name "hpc-demo-compute-cpu" \
  --root-device-name "/dev/sda1" \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=8}" \
  --virtualization-type hvm \
  --architecture x86_64 \
  --query 'ImageId' \
  --output text)
echo "Created CPU AMI: $CPU_AMI_ID"

GPU_AMI_ID=$(aws_local ec2 register-image \
  --name "hpc-demo-compute-gpu" \
  --root-device-name "/dev/sda1" \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=8}" \
  --virtualization-type hvm \
  --architecture x86_64 \
  --query 'ImageId' \
  --output text)
echo "Created GPU AMI: $GPU_AMI_ID"

# Create aws-resources.txt file
echo "Creating aws-resources.txt file..."
cat << RESOURCES > /tmp/localstack/aws-resources.txt
# AWS Resources for LocalStack testing
AWS_REGION=us-west-2
VPC_ID=$VPC_ID
PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID
PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID
IGW_ID=$IGW_ID
PUBLIC_RTB_ID=$PUBLIC_RTB_ID
PRIVATE_RTB_ID=$PRIVATE_RTB_ID
BASTION_SG_ID=$BASTION_SG_ID
COMPUTE_SG_ID=$COMPUTE_SG_ID
CPU_AMI_ID=$CPU_AMI_ID
GPU_AMI_ID=$GPU_AMI_ID
POLICY_ARN=$POLICY_ARN
RESOURCES

echo "LocalStack initialization complete. Resources created for testing."