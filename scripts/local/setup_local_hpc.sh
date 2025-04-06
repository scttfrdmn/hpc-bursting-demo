#!/bin/bash
# Main script for local HPC system setup
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Log function
log() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

log "INFO" "Starting local HPC system setup..."

# Step 1: System update and basic configuration
log "INFO" "Running system update and basic configuration..."
./01_system_update.sh
if [ $? -ne 0 ]; then
  log "ERROR" "System update failed. Exiting."
  exit 1
fi

# Step 2: Set up NFS server
log "INFO" "Setting up NFS server..."
./02_setup_nfs.sh
if [ $? -ne 0 ]; then
  log "ERROR" "NFS setup failed. Exiting."
  exit 1
fi

# Step 3: Set up LDAP server
log "INFO" "Setting up LDAP server..."
./03_setup_ldap.sh
if [ $? -ne 0 ]; then
  log "ERROR" "LDAP setup failed. Exiting."
  exit 1
fi

# Step 4: Set up Slurm
log "INFO" "Setting up Slurm..."
./04_setup_slurm.sh
if [ $? -ne 0 ]; then
  log "ERROR" "Slurm setup failed. Exiting."
  exit 1
fi

# Step 5: Set up WireGuard
log "INFO" "Setting up WireGuard..."
./05_setup_wireguard.sh
if [ $? -ne 0 ]; then
  log "ERROR" "WireGuard setup failed. Exiting."
  exit 1
fi

# Setup complete
log "INFO" "Local HPC system setup completed successfully."
log "INFO" "Next, run the AWS infrastructure setup script."
