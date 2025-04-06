# Delete Route 53 hosted zone
if [ ! -z "$HOSTED_ZONE_ID" ]; then
  log "Deleting Route 53 records..."
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
  
  log "Deleting hosted zone..."
  aws route53 delete-hosted-zone \
    --id $HOSTED_ZONE_ID
fi

# Delete key pair
log "Deleting key pair..."
aws ec2 delete-key-pair \
  --key-name hpc-demo-key \
  --region $AWS_REGION

# Delete security groups
if [ ! -z "$COMPUTE_SG_ID" ]; then
  log "Deleting compute security group..."
  aws ec2 delete-security-group \
    --group-id $COMPUTE_SG_ID \
    --region $AWS_REGION || true
fi

if [ ! -z "$BASTION_SG_ID" ]; then
  log "Deleting bastion security group..."
  aws ec2 delete-security-group \
    --group-id $BASTION_SG_ID \
    --region $AWS_REGION || true
fi

# Delete route tables
if [ ! -z "$PRIVATE_RTB_ID" ]; then
  log "Deleting private route table..."
  aws ec2 delete-route-table \
    --route-table-id $PRIVATE_RTB_ID \
    --region $AWS_REGION || true
fi

if [ ! -z "$PUBLIC_RTB_ID" ]; then
  log "Deleting public route table..."
  aws ec2 delete-route-table \
    --route-table-id $PUBLIC_RTB_ID \
    --region $AWS_REGION || true
fi

# Delete subnets
if [ ! -z "$PRIVATE_SUBNET_ID" ]; then
  log "Deleting private subnet..."
  aws ec2 delete-subnet \
    --subnet-id $PRIVATE_SUBNET_ID \
    --region $AWS_REGION || true
fi

if [ ! -z "$PUBLIC_SUBNET_ID" ]; then
  log "Deleting public subnet..."
  aws ec2 delete-subnet \
    --subnet-id $PUBLIC_SUBNET_ID \
    --region $AWS_REGION || true
fi

# Detach and delete internet gateway
if [ ! -z "$IGW_ID" ] && [ ! -z "$VPC_ID" ]; then
  log "Detaching internet gateway..."
  aws ec2 detach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $AWS_REGION || true
    
  log "Deleting internet gateway..."
  aws ec2 delete-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --region $AWS_REGION || true
fi

# Delete VPC
if [ ! -z "$VPC_ID" ]; then
  log "Deleting VPC..."
  aws ec2 delete-vpc \
    --vpc-id $VPC_ID \
    --region $AWS_REGION || true
fi

# Detach policy from IAM user
if [ ! -z "$POLICY_ARN" ]; then
  log "Detaching policy from user..."
  aws iam detach-user-policy \
    --user-name slurm-aws-plugin \
    --policy-arn $POLICY_ARN || true
    
  log "Deleting policy..."
  aws iam delete-policy \
    --policy-arn $POLICY_ARN || true
fi

# Delete access key
log "Deleting access key..."
if [ ! -z "$ACCESS_KEY_ID" ]; then
  aws iam delete-access-key \
    --user-name slurm-aws-plugin \
    --access-key-id $ACCESS_KEY_ID || true
fi

# Delete IAM user
log "Deleting IAM user..."
aws iam delete-user \
  --user-name slurm-aws-plugin || true

log "Cleanup completed successfully"
