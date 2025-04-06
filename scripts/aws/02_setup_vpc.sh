#!/bin/bash
# Setup VPC, subnets, and security groups
set -e

# Load resource IDs
source ../aws-resources.txt

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.1.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=hpc-demo-vpc}]' \
    --region $AWS_REGION \
    --query 'Vpc.VpcId' --output text)
echo "Created VPC: $VPC_ID"

# Enable DNS hostnames in the VPC
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames '{"Value":true}' \
    --region $AWS_REGION

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=hpc-demo-igw}]' \
    --region $AWS_REGION \
    --query 'InternetGateway.InternetGatewayId' --output text)
echo "Created Internet Gateway: $IGW_ID"

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $AWS_REGION
echo "Attached Internet Gateway to VPC"

# Create public subnet
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.1.0.0/24 \
    --availability-zone ${AWS_REGION}a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=hpc-demo-public}]' \
    --region $AWS_REGION \
    --query 'Subnet.SubnetId' --output text)
echo "Created public subnet: $PUBLIC_SUBNET_ID"

# Create private subnet
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.1.1.0/24 \
    --availability-zone ${AWS_REGION}a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=hpc-demo-private}]' \
    --region $AWS_REGION \
    --query 'Subnet.SubnetId' --output text)
echo "Created private subnet: $PRIVATE_SUBNET_ID"
# Create route table for public subnet
PUBLIC_RTB_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=hpc-demo-public-rtb}]' \
    --region $AWS_REGION \
    --query 'RouteTable.RouteTableId' --output text)
echo "Created public route table: $PUBLIC_RTB_ID"

# Create route to Internet Gateway
aws ec2 create-route \
    --route-table-id $PUBLIC_RTB_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --region $AWS_REGION
echo "Created route to Internet Gateway"

# Associate public subnet with public route table
aws ec2 associate-route-table \
    --route-table-id $PUBLIC_RTB_ID \
    --subnet-id $PUBLIC_SUBNET_ID \
    --region $AWS_REGION
echo "Associated public subnet with public route table"

# Create route table for private subnet
PRIVATE_RTB_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=hpc-demo-private-rtb}]' \
    --region $AWS_REGION \
    --query 'RouteTable.RouteTableId' --output text)
echo "Created private route table: $PRIVATE_RTB_ID"

# Associate private subnet with private route table
aws ec2 associate-route-table \
    --route-table-id $PRIVATE_RTB_ID \
    --subnet-id $PRIVATE_SUBNET_ID \
    --region $AWS_REGION
echo "Associated private subnet with private route table"

# Create security group for bastion host
BASTION_SG_ID=$(aws ec2 create-security-group \
    --group-name hpc-demo-bastion-sg \
    --description "Security group for HPC demo bastion host" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' --output text)
echo "Created bastion security group: $BASTION_SG_ID"

# Allow SSH from anywhere to bastion
aws ec2 authorize-security-group-ingress \
    --group-id $BASTION_SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION
echo "Allowed SSH from anywhere to bastion"

# Allow WireGuard UDP port
aws ec2 authorize-security-group-ingress \
    --group-id $BASTION_SG_ID \
    --protocol udp \
    --port 51820 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION
echo "Allowed WireGuard UDP port"

# Create security group for compute nodes
COMPUTE_SG_ID=$(aws ec2 create-security-group \
    --group-name hpc-demo-compute-sg \
    --description "Security group for HPC demo compute nodes" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' --output text)
echo "Created compute security group: $COMPUTE_SG_ID"

# Allow all traffic from private subnet to compute nodes
aws ec2 authorize-security-group-ingress \
    --group-id $COMPUTE_SG_ID \
    --protocol all \
    --source-group $COMPUTE_SG_ID \
    --region $AWS_REGION
echo "Allowed all traffic between compute nodes"

# Allow all traffic from bastion to compute nodes
aws ec2 authorize-security-group-ingress \
    --group-id $COMPUTE_SG_ID \
    --protocol all \
    --source-group $BASTION_SG_ID \
    --region $AWS_REGION
echo "Allowed all traffic from bastion to compute nodes"

# Create Route 53 private hosted zone
HOSTED_ZONE_ID=$(aws route53 create-hosted-zone \
    --name "hpc-demo.internal" \
    --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
    --caller-reference "hpc-demo-$(date +%s)" \
    --hosted-zone-config PrivateZone=true \
    --query 'HostedZone.Id' --output text | sed 's/\/hostedzone\///')
echo "Created private hosted zone: $HOSTED_ZONE_ID"

# Update aws-resources.txt
cat << RESOURCES >> ../aws-resources.txt
VPC_ID=$VPC_ID
PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID
PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID
PUBLIC_RTB_ID=$PUBLIC_RTB_ID
PRIVATE_RTB_ID=$PRIVATE_RTB_ID
BASTION_SG_ID=$BASTION_SG_ID
COMPUTE_SG_ID=$COMPUTE_SG_ID
HOSTED_ZONE_ID=$HOSTED_ZONE_ID
RESOURCES

echo "VPC and networking setup completed successfully."
