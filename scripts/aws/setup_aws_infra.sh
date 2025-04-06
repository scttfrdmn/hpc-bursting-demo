#!/bin/bash
# Main script for AWS infrastructure setup
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Log function
log() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

log "INFO" "Starting AWS infrastructure setup..."

# Step 1: Create IAM user and policy
log "INFO" "Creating IAM user and policy..."
./01_create_iam_user.sh
if [ $? -ne 0 ]; then
  log "ERROR" "IAM user creation failed. Exiting."
  exit 1
fi

# Step 2: Set up VPC and networking
log "INFO" "Setting up VPC and networking..."
./02_setup_vpc.sh
if [ $? -ne 0 ]; then
  log "ERROR" "VPC setup failed. Exiting."
  exit 1
fi

# Step 3: Launch bastion and set up WireGuard
log "INFO" "Launching bastion and setting up WireGuard..."
./03_setup_bastion.sh
if [ $? -ne 0 ]; then
  log "ERROR" "Bastion setup failed. Exiting."
  exit 1
fi

# Step 4: Create AMIs for compute nodes
log "INFO" "Creating AMIs for compute nodes..."
./04_create_amis.sh
if [ $? -ne 0 ]; then
  log "ERROR" "AMI creation failed. Exiting."
  exit 1
fi

# Step 5: Create launch template
log "INFO" "Creating launch template..."
./05_create_launch_template.sh
if [ $? -ne 0 ]; then
  log "ERROR" "Launch template creation failed. Exiting."
  exit 1
fi

# Step 6: Configure Slurm AWS Plugin
log "INFO" "Configuring Slurm AWS Plugin..."
./06_configure_slurm_aws_plugin.sh
if [ $? -ne 0 ]; then
  log "ERROR" "Slurm AWS Plugin configuration failed. Exiting."
  exit 1
fi

# Setup complete
log "INFO" "AWS infrastructure setup completed successfully."
log "INFO" "You can now run the test script to verify the setup."
