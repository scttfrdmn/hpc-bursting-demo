#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Delete AWS resources created for HPC bursting
set -e

# Parse command line arguments
FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --force   Skip confirmation prompt"
      echo "  --help    Show this help message"
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

# Load resource IDs from file if it exists
if [ -f "../aws-resources.txt" ]; then
  log "INFO" "Loading resource IDs from aws-resources.txt..."
  source ../aws-resources.txt
else
  log "WARN" "aws-resources.txt not found. Will try to identify resources by tag."
  AWS_REGION=${AWS_REGION:-"us-west-2"}
fi

# Add confirmation unless --force is used
if [ "$FORCE" != "true" ]; then
  echo ""
  echo "⚠️  WARNING: This will delete ALL resources created for HPC Bursting Demo ⚠️"
  echo "Including: EC2 instances, AMIs, Launch Templates, VPC, IAM roles, etc."
  echo ""
  read -p "Are you sure you want to continue? (y/N): " confirm
  if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    log "INFO" "Cleanup cancelled."
    exit 0
  fi
  echo ""
fi

# Terminate all running instances with the project tag
log "INFO" "Terminating EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=HPC-Bursting-Demo" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text \
  --region $AWS_REGION)

if [ ! -z "$INSTANCE_IDS" ]; then
  log "INFO" "Found instances to terminate: $INSTANCE_IDS"
  aws ec2 terminate-instances \
    --instance-ids $INSTANCE_IDS \
    --region $AWS_REGION

  log "INFO" "Waiting for instances to terminate..."
  aws ec2 wait instance-terminated \
    --instance-ids $INSTANCE_IDS \
    --region $AWS_REGION
else
  log "INFO" "No running instances found."
fi

# Delete launch templates
log "INFO" "Deleting launch templates..."
LAUNCH_TEMPLATES=$(aws ec2 describe-launch-templates \
  --filters "Name=launch-template-name,Values=hpc-demo-compute*" \
  --query "LaunchTemplates[].LaunchTemplateId" \
  --output text \
  --region $AWS_REGION)

if [ ! -z "$LAUNCH_TEMPLATES" ]; then
  for LT_ID in $LAUNCH_TEMPLATES; do
    log "INFO" "Deleting launch template: $LT_ID"
    aws ec2 delete-launch-template \
      --launch-template-id $LT_ID \
      --region $AWS_REGION
  done
else
  log "INFO" "No launch templates found."
fi

# Deregister AMIs
log "INFO" "Deregistering AMIs..."
AMIS=$(aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=hpc-demo-compute*" \
  --query "Images[].ImageId" \
  --output text \
  --region $AWS_REGION)

if [ ! -z "$AMIS" ]; then
  for AMI_ID in $AMIS; do
    log "INFO" "Deregistering AMI: $AMI_ID"
    
    # Get snapshots associated with this AMI
    SNAPSHOTS=$(aws ec2 describe-images \
      --image-ids $AMI_ID \
      --query "Images[].BlockDeviceMappings[].Ebs.SnapshotId" \
      --output text \
      --region $AWS_REGION)
    
    # Deregister the AMI
    aws ec2 deregister-image \
      --image-id $AMI_ID \
      --region $AWS_REGION
    
    # Delete associated snapshots
    if [ ! -z "$SNAPSHOTS" ]; then
      for SNAPSHOT_ID in $SNAPSHOTS; do
        log "INFO" "Deleting snapshot: $SNAPSHOT_ID"
        aws ec2 delete-snapshot \
          --snapshot-id $SNAPSHOT_ID \
          --region $AWS_REGION
      done
    fi
  done
else
  log "INFO" "No AMIs found."
fi

# Delete bastion host if still running
if [ ! -z "$BASTION_ID" ]; then
  log "INFO" "Terminating bastion host..."
  aws ec2 terminate-instances \
    --instance-ids $BASTION_ID \
    --region $AWS_REGION || true
  
  # Wait for bastion to terminate before proceeding
  aws ec2 wait instance-terminated \
    --instance-ids $BASTION_ID \
    --region $AWS_REGION || true
fi

# Delete Route 53 hosted zone
if [ ! -z "$HOSTED_ZONE_ID" ]; then
  log "INFO" "Deleting Route 53 records..."
  # Get all record sets except NS and SOA
  RECORDSETS=$(aws route53 list-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query "ResourceRecordSets[?!(Type=='NS' || Type=='SOA')]" \
    --output json)
  
  # Create change batch file if there are records to delete
  if [ "$RECORDSETS" != "[]" ]; then
    echo '{"Changes":[' > /tmp/change-batch.json
    first=true
    
    for record in $(echo $RECORDSETS | jq -c '.[]'); do
      if [ "$first" = true ]; then
        first=false
      else
        echo ',' >> /tmp/change-batch.json
      fi
      
      # Format for change batch
      echo "{\"Action\":\"DELETE\",\"ResourceRecordSet\":$record}" >> /tmp/change-batch.json
    done
    
    echo ']}' >> /tmp/change-batch.json
    
    # Delete records
    aws route53 change-resource-record-sets \
      --hosted-zone-id $HOSTED_ZONE_ID \
      --change-batch file:///tmp/change-batch.json
  fi
  
  log "INFO" "Deleting hosted zone..."
  aws route53 delete-hosted-zone \
    --id $HOSTED_ZONE_ID || true
else
  # Try to find hosted zone by name
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='hpc-demo.internal.'].Id" \
    --output text | sed 's/\/hostedzone\///')
  
  if [ ! -z "$HOSTED_ZONE_ID" ]; then
    log "INFO" "Found hosted zone by name: $HOSTED_ZONE_ID"
    log "INFO" "Deleting Route 53 records..."
    # Get all record sets except NS and SOA
    RECORDSETS=$(aws route53 list-resource-record-sets \
      --hosted-zone-id $HOSTED_ZONE_ID \
      --query "ResourceRecordSets[?!(Type=='NS' || Type=='SOA')]" \
      --output json)
    
    # Create change batch file if there are records to delete
    if [ "$RECORDSETS" != "[]" ]; then
      echo '{"Changes":[' > /tmp/change-batch.json
      first=true
      
      for record in $(echo $RECORDSETS | jq -c '.[]'); do
        if [ "$first" = true ]; then
          first=false
        else
          echo ',' >> /tmp/change-batch.json
        fi
        
        # Format for change batch
        echo "{\"Action\":\"DELETE\",\"ResourceRecordSet\":$record}" >> /tmp/change-batch.json
      done
      
      echo ']}' >> /tmp/change-batch.json
      
      # Delete records
      aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch file:///tmp/change-batch.json
    fi
    
    log "INFO" "Deleting hosted zone..."
    aws route53 delete-hosted-zone \
      --id $HOSTED_ZONE_ID || true
  fi
fi

# Delete key pair
log "INFO" "Deleting key pair..."
aws ec2 delete-key-pair \
  --key-name hpc-demo-key \
  --region $AWS_REGION || true

# Check for and delete any elastic network interfaces
log "INFO" "Checking for elastic network interfaces..."
ENIS=$(aws ec2 describe-network-interfaces \
  --filters "Name=tag:Project,Values=HPC-Bursting-Demo" \
  --query "NetworkInterfaces[].NetworkInterfaceId" \
  --output text \
  --region $AWS_REGION)

if [ -z "$ENIS" ]; then
  # If no ENIs found with tag, try to find by attachment to the VPC
  if [ ! -z "$VPC_ID" ]; then
    ENIS=$(aws ec2 describe-network-interfaces \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query "NetworkInterfaces[].NetworkInterfaceId" \
      --output text \
      --region $AWS_REGION)
  fi
fi

if [ ! -z "$ENIS" ]; then
  for ENI_ID in $ENIS; do
    log "INFO" "Found elastic network interface: $ENI_ID"
    
    # Check if ENI is attached to an instance
    ATTACHMENT_STATE=$(aws ec2 describe-network-interfaces \
      --network-interface-ids $ENI_ID \
      --query "NetworkInterfaces[].Attachment.Status" \
      --output text \
      --region $AWS_REGION)
    
    if [ "$ATTACHMENT_STATE" == "attached" ]; then
      log "INFO" "Detaching network interface: $ENI_ID"
      ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
        --network-interface-ids $ENI_ID \
        --query "NetworkInterfaces[].Attachment.AttachmentId" \
        --output text \
        --region $AWS_REGION)
      
      aws ec2 detach-network-interface \
        --attachment-id $ATTACHMENT_ID \
        --force \
        --region $AWS_REGION
      
      # Wait for detachment to complete
      sleep 15
    fi
    
    log "INFO" "Deleting network interface: $ENI_ID"
    aws ec2 delete-network-interface \
      --network-interface-id $ENI_ID \
      --region $AWS_REGION || true
  done
else
  log "INFO" "No elastic network interfaces found."
fi

# Delete security groups
if [ ! -z "$COMPUTE_SG_ID" ]; then
  log "INFO" "Deleting compute security group..."
  aws ec2 delete-security-group \
    --group-id $COMPUTE_SG_ID \
    --region $AWS_REGION || true
else
  # Try to find security group by name
  COMPUTE_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=hpc-demo-compute-sg" \
    --query "SecurityGroups[].GroupId" \
    --output text \
    --region $AWS_REGION)
  
  if [ ! -z "$COMPUTE_SG_ID" ]; then
    log "INFO" "Found compute security group by name: $COMPUTE_SG_ID"
    log "INFO" "Deleting compute security group..."
    aws ec2 delete-security-group \
      --group-id $COMPUTE_SG_ID \
      --region $AWS_REGION || true
  fi
fi

if [ ! -z "$BASTION_SG_ID" ]; then
  log "INFO" "Deleting bastion security group..."
  aws ec2 delete-security-group \
    --group-id $BASTION_SG_ID \
    --region $AWS_REGION || true
else
  # Try to find security group by name
  BASTION_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=hpc-demo-bastion-sg" \
    --query "SecurityGroups[].GroupId" \
    --output text \
    --region $AWS_REGION)
  
  if [ ! -z "$BASTION_SG_ID" ]; then
    log "INFO" "Found bastion security group by name: $BASTION_SG_ID"
    log "INFO" "Deleting bastion security group..."
    aws ec2 delete-security-group \
      --group-id $BASTION_SG_ID \
      --region $AWS_REGION || true
  fi
fi

# Delete route tables
if [ ! -z "$PRIVATE_RTB_ID" ]; then
  log "INFO" "Deleting private route table..."
  aws ec2 delete-route-table \
    --route-table-id $PRIVATE_RTB_ID \
    --region $AWS_REGION || true
fi

if [ ! -z "$PUBLIC_RTB_ID" ]; then
  log "INFO" "Deleting public route table..."
  aws ec2 delete-route-table \
    --route-table-id $PUBLIC_RTB_ID \
    --region $AWS_REGION || true
fi

# Delete subnets
if [ ! -z "$PRIVATE_SUBNET_ID" ]; then
  log "INFO" "Deleting private subnet..."
  aws ec2 delete-subnet \
    --subnet-id $PRIVATE_SUBNET_ID \
    --region $AWS_REGION || true
fi

if [ ! -z "$PUBLIC_SUBNET_ID" ]; then
  log "INFO" "Deleting public subnet..."
  aws ec2 delete-subnet \
    --subnet-id $PUBLIC_SUBNET_ID \
    --region $AWS_REGION || true
fi

# Detach and delete internet gateway
if [ ! -z "$IGW_ID" ] && [ ! -z "$VPC_ID" ]; then
  log "INFO" "Detaching internet gateway..."
  aws ec2 detach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $AWS_REGION || true
    
  log "INFO" "Deleting internet gateway..."
  aws ec2 delete-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --region $AWS_REGION || true
elif [ -z "$IGW_ID" ] && [ ! -z "$VPC_ID" ]; then
  # Try to find internet gateway by VPC ID
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query "InternetGateways[].InternetGatewayId" \
    --output text \
    --region $AWS_REGION)
  
  if [ ! -z "$IGW_ID" ]; then
    log "INFO" "Found internet gateway by VPC ID: $IGW_ID"
    log "INFO" "Detaching internet gateway..."
    aws ec2 detach-internet-gateway \
      --internet-gateway-id $IGW_ID \
      --vpc-id $VPC_ID \
      --region $AWS_REGION || true
    
    log "INFO" "Deleting internet gateway..."
    aws ec2 delete-internet-gateway \
      --internet-gateway-id $IGW_ID \
      --region $AWS_REGION || true
  fi
fi

# Delete VPC
if [ ! -z "$VPC_ID" ]; then
  log "INFO" "Deleting VPC..."
  aws ec2 delete-vpc \
    --vpc-id $VPC_ID \
    --region $AWS_REGION || true
else
  # Try to find VPC by name tag
  VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=hpc-demo-vpc" \
    --query "Vpcs[].VpcId" \
    --output text \
    --region $AWS_REGION)
  
  if [ ! -z "$VPC_ID" ]; then
    log "INFO" "Found VPC by name tag: $VPC_ID"
    log "INFO" "Deleting VPC..."
    aws ec2 delete-vpc \
      --vpc-id $VPC_ID \
      --region $AWS_REGION || true
  fi
fi

# Detach policy from IAM user
if [ ! -z "$POLICY_ARN" ]; then
  log "INFO" "Detaching policy from user..."
  aws iam detach-user-policy \
    --user-name slurm-aws-plugin \
    --policy-arn $POLICY_ARN || true
    
  log "INFO" "Deleting policy..."
  aws iam delete-policy \
    --policy-arn $POLICY_ARN || true
else
  # Try to find policy by name
  POLICY_ARN=$(aws iam list-policies \
    --scope Local \
    --query "Policies[?PolicyName=='slurm-aws-plugin-policy'].Arn" \
    --output text)
  
  if [ ! -z "$POLICY_ARN" ]; then
    log "INFO" "Found policy by name: $POLICY_ARN"
    log "INFO" "Detaching policy from user..."
    aws iam detach-user-policy \
      --user-name slurm-aws-plugin \
      --policy-arn $POLICY_ARN || true
    
    log "INFO" "Deleting policy..."
    aws iam delete-policy \
      --policy-arn $POLICY_ARN || true
  fi
fi

# Delete access key
if [ ! -z "$ACCESS_KEY_ID" ]; then
  log "INFO" "Deleting access key..."
  aws iam delete-access-key \
    --user-name slurm-aws-plugin \
    --access-key-id $ACCESS_KEY_ID || true
else
  # Get all access keys for the user
  ACCESS_KEYS=$(aws iam list-access-keys \
    --user-name slurm-aws-plugin \
    --query "AccessKeyMetadata[].AccessKeyId" \
    --output text || true)
  
  for KEY_ID in $ACCESS_KEYS; do
    log "INFO" "Found access key: $KEY_ID"
    log "INFO" "Deleting access key..."
    aws iam delete-access-key \
      --user-name slurm-aws-plugin \
      --access-key-id $KEY_ID || true
  done
fi

# Delete CloudFormation stack
log "INFO" "Checking for CloudFormation stack..."
STACK_EXISTS=$(aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query "StackSummaries[?contains(StackName,'hpc-bursting')].StackName" \
  --output text \
  --region $AWS_REGION)

if [ ! -z "$STACK_EXISTS" ]; then
  log "INFO" "Found CloudFormation stack: $STACK_EXISTS"
  log "INFO" "Deleting CloudFormation stack..."
  aws cloudformation delete-stack \
    --stack-name $STACK_EXISTS \
    --region $AWS_REGION
  
  log "INFO" "Waiting for stack deletion to complete..."
  aws cloudformation wait stack-delete-complete \
    --stack-name $STACK_EXISTS \
    --region $AWS_REGION
else
  log "INFO" "No CloudFormation stack found."
fi

# Delete CloudWatch Logs
log "INFO" "Cleaning up CloudWatch log groups..."
LOG_GROUPS=$(aws logs describe-log-groups \
  --log-group-name-prefix "/aws/ec2/hpc-demo" \
  --query "logGroups[].logGroupName" \
  --output text \
  --region $AWS_REGION)

if [ ! -z "$LOG_GROUPS" ]; then
  for LOG_GROUP in $LOG_GROUPS; do
    log "INFO" "Deleting log group: $LOG_GROUP"
    aws logs delete-log-group \
      --log-group-name $LOG_GROUP \
      --region $AWS_REGION
  done
else
  log "INFO" "No CloudWatch log groups found."
fi

# Delete IAM user
log "INFO" "Deleting IAM user..."
aws iam delete-user \
  --user-name slurm-aws-plugin || true

# Clean up local files
log "INFO" "Cleaning up local files..."
rm -f slurm-aws-policy.json || true
rm -f slurm-aws-credentials.json || true
rm -f hpc-demo-key.pem || true
rm -f bastion-userdata.sh || true
rm -f bastion-wireguard-info.txt || true
rm -f cpu-userdata.sh || true
rm -f gpu-userdata.sh || true
rm -f ../cloudformation/ami-parameters.json || true

log "INFO" "Cleanup completed successfully."
echo ""
echo "✅ All HPC Bursting Demo resources in AWS have been deleted:"
echo "   - EC2 instances and bastion host"
echo "   - AMIs and associated snapshots"
echo "   - Launch templates"
echo "   - VPC resources (subnets, route tables, security groups, etc.)"
echo "   - Elastic Network Interfaces"
echo "   - Route53 hosted zone and records"
echo "   - CloudWatch log groups"
echo "   - IAM user, access keys, and policies"
echo "   - CloudFormation stack (if used)"
echo "   - Local temporary files"
echo ""
echo "To complete cleanup of local resources, you may need to:"
echo "1. Remove WireGuard configuration: sudo rm /etc/wireguard/wg0.conf"
echo "2. Remove AWS plugin configuration: sudo rm -rf /etc/slurm/aws"
echo "3. Update Slurm configuration to remove cloud nodes: sudo vim /etc/slurm/slurm.conf"
echo "4. Restart Slurm services: sudo systemctl restart slurmctld"
echo ""
echo "You can monitor AWS costs with: ../monitor-aws-costs.sh"
echo ""