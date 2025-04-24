#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Launch bastion host and set up WireGuard
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
  echo "Test mode: Using mock bastion host and WireGuard setup"
  
  # Mock resource IDs and values
  BASTION_ID="i-bastion-test12345"
  BASTION_PUBLIC_IP="192.0.2.123"  # Documentation/test IP
  BASTION_PUBLIC_KEY="mockWireGuardPublicKey123456789abcdefghijklmnopqrstuvwxyz="
  ARCH="x86_64"
  
  # Update resources file and exit
  cat << RESOURCES >> ../aws-resources.txt
BASTION_ID=$BASTION_ID
BASTION_PUBLIC_IP=$BASTION_PUBLIC_IP
BASTION_PUBLIC_KEY=$BASTION_PUBLIC_KEY
ARCH=$ARCH
RESOURCES

  echo "Test mode: Mock bastion host and WireGuard setup completed successfully."
  exit 0
fi

# Determine local architecture
LOCAL_ARCH=$(uname -m)
if [ "$LOCAL_ARCH" == "aarch64" ]; then
    ARCH="arm64"
    INSTANCE_TYPE="t4g.micro"
else
    ARCH="x86_64"
    INSTANCE_TYPE="t3.micro"
fi

echo "Local architecture: $LOCAL_ARCH, using $ARCH instances"

# Get the latest Rocky 9 AMI ID
AMI_ID=$(aws ec2 describe-images \
    --owners 679593333241 \
    --filters "Name=name,Values=Rocky-9-${ARCH}*" "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text \
    --region $AWS_REGION)
echo "Using Rocky 9 AMI: $AMI_ID"

# Generate key pair for bastion
aws ec2 create-key-pair \
    --key-name hpc-demo-key \
    --query "KeyMaterial" \
    --output text \
    --region $AWS_REGION > hpc-demo-key.pem
chmod 400 hpc-demo-key.pem
echo "Created key pair: hpc-demo-key"

# Get local WireGuard public key
LOCAL_PUBLIC_KEY=$(sudo cat /etc/wireguard/publickey)

# Create user data script for bastion
cat << EOF_USERDATA > bastion-userdata.sh
#!/bin/bash
# Update system
dnf update -y

# Install WireGuard
dnf install -y wireguard-tools

# Configure WireGuard
cd /etc/wireguard
umask 077
wg genkey | tee privatekey | wg pubkey > publickey

# Get the keys
PRIVATE_KEY=\$(cat privatekey)
PUBLIC_KEY=\$(cat publickey)

# Create WireGuard configuration
cat << WGEOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = \$PRIVATE_KEY
Address = 10.0.0.2/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $LOCAL_PUBLIC_KEY
AllowedIPs = 10.0.0.1/32, 10.0.0.0/24
WGEOF

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Enable and start WireGuard
systemctl enable --now wg-quick@wg0

# Create a script to output configuration info
cat << SCRIPT > /home/rocky/wireguard-info.sh
#!/bin/bash
echo "WireGuard Public Key: \$(cat /etc/wireguard/publickey)"
echo "WireGuard IP: 10.0.0.2"
echo "WireGuard Port: 51820"
echo "Public IP: \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
SCRIPT

chmod +x /home/rocky/wireguard-info.sh
EOF_USERDATA

# Launch bastion instance
echo "Launching bastion instance..."
BASTION_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name hpc-demo-key \
    --security-group-ids $BASTION_SG_ID \
    --subnet-id $PUBLIC_SUBNET_ID \
    --associate-public-ip-address \
    --user-data file://bastion-userdata.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=hpc-demo-bastion},{Key=Project,Value=HPC-Bursting-Demo}]' \
    --region $AWS_REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Launched bastion instance: $BASTION_ID"

# Wait for the instance to be running
echo "Waiting for bastion instance to be running..."
aws ec2 wait instance-running \
    --instance-ids $BASTION_ID \
    --region $AWS_REGION

# Get the public IP address
BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $BASTION_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
echo "Bastion public IP: $BASTION_PUBLIC_IP"

# Wait for instance initialization
echo "Waiting for instance initialization (60 seconds)..."
sleep 60

# Get WireGuard information from the bastion
echo "Fetching WireGuard information from bastion..."
ssh -i hpc-demo-key.pem -o StrictHostKeyChecking=no rocky@$BASTION_PUBLIC_IP "bash /home/rocky/wireguard-info.sh" > bastion-wireguard-info.txt

# Extract WireGuard public key
BASTION_PUBLIC_KEY=$(grep "WireGuard Public Key" bastion-wireguard-info.txt | awk '{print $4}')

# Update local WireGuard configuration
echo "Updating local WireGuard configuration..."
cat << WGLOCAL | sudo tee -a /etc/wireguard/wg0.conf
[Peer]
PublicKey = $BASTION_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32, 10.1.0.0/16
Endpoint = $BASTION_PUBLIC_IP:51820
PersistentKeepalive = 25
WGLOCAL

# Enable and start WireGuard on local system
echo "Starting local WireGuard interface..."
sudo systemctl enable --now wg-quick@wg0

# Add a route for the private subnet through the WireGuard interface
echo "Adding route to AWS private subnet..."
sudo ip route add 10.1.1.0/24 via 10.0.0.2 dev wg0

# Update bastion route table to route to local network
echo "Configuring bastion routing..."
ssh -i hpc-demo-key.pem rocky@$BASTION_PUBLIC_IP "sudo ip route add 10.0.0.1/32 dev wg0"

# Create a route in the private route table to the local HPC system via the bastion
echo "Configuring AWS VPC routing to local HPC system..."
aws ec2 create-route \
    --route-table-id $PRIVATE_RTB_ID \
    --destination-cidr-block 10.0.0.0/24 \
    --instance-id $BASTION_ID \
    --region $AWS_REGION
echo "Created route to local HPC network via bastion"

# Create DNS records for the HPC controller
echo "Creating DNS records..."
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '{
        "Changes": [
            {
                "Action": "CREATE",
                "ResourceRecordSet": {
                    "Name": "controller.hpc-demo.internal",
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [
                        {"Value": "10.0.0.1"}
                    ]
                }
            },
            {
                "Action": "CREATE",
                "ResourceRecordSet": {
                    "Name": "nfs.hpc-demo.internal",
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [
                        {"Value": "10.0.0.1"}
                    ]
                }
            },
            {
                "Action": "CREATE",
                "ResourceRecordSet": {
                    "Name": "ldap.hpc-demo.internal",
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [
                        {"Value": "10.0.0.1"}
                    ]
                }
            }
        ]
    }'

# Update aws-resources.txt
cat << RESOURCES >> ../aws-resources.txt
BASTION_ID=$BASTION_ID
BASTION_PUBLIC_IP=$BASTION_PUBLIC_IP
BASTION_PUBLIC_KEY=$BASTION_PUBLIC_KEY
ARCH=$ARCH
RESOURCES

echo "Bastion host and WireGuard setup completed successfully."
