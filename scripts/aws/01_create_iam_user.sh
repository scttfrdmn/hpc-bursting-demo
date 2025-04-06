#!/bin/bash
# Create IAM user and policy for Slurm AWS Plugin
set -e

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
POLICY_ARN=$(aws iam create-policy \
    --policy-name slurm-aws-plugin-policy \
    --policy-document file://slurm-aws-policy.json \
    --query 'Policy.Arn' --output text)

echo "Created policy: $POLICY_ARN"

# Create IAM user for Slurm AWS Plugin
echo "Creating IAM user..."
aws iam create-user --user-name slurm-aws-plugin

# Attach policy to user
echo "Attaching policy to user..."
aws iam attach-user-policy \
    --user-name slurm-aws-plugin \
    --policy-arn $POLICY_ARN

# Create access key for the user
echo "Creating access key..."
aws iam create-access-key \
    --user-name slurm-aws-plugin > slurm-aws-credentials.json

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
