#!/bin/bash
# NFS server setup
set -e

# Install NFS server packages
echo "Installing NFS server packages..."
sudo dnf install -y nfs-utils

# Create directories for NFS shares
echo "Creating NFS export directories..."
sudo mkdir -p /export/home
sudo mkdir -p /export/apps
sudo mkdir -p /export/scratch
sudo mkdir -p /export/slurm
sudo mkdir -p /export/logs

# Set permissions
sudo chmod 755 /export
sudo chmod 777 /export/scratch
sudo chmod 755 /export/logs

# Configure NFS exports
echo "Configuring NFS exports..."
cat << 'EXPORTS' | sudo tee /etc/exports
/export/home    *(rw,sync,no_root_squash)
/export/apps    *(rw,sync,no_root_squash)
/export/scratch *(rw,sync,no_root_squash)
/export/slurm   *(rw,sync,no_root_squash)
/export/logs    *(rw,sync,no_root_squash)
EXPORTS

# Enable and start NFS services
echo "Starting NFS services..."
sudo systemctl enable --now rpcbind nfs-server

# Export the shares
sudo exportfs -a

echo "NFS server setup completed."
