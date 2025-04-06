#!/bin/bash
# System update and basic configuration
set -e

# Update the system
echo "Updating system packages..."
sudo dnf update -y

# Install basic utilities
echo "Installing basic utilities..."
sudo dnf install -y vim wget curl git tar zip unzip bind-utils net-tools tcpdump jq

# Set hostname
echo "Setting hostname..."
sudo hostnamectl set-hostname hpc-local.demo.local

# Add hostname to /etc/hosts
echo "Updating /etc/hosts..."
echo "127.0.0.1 hpc-local.demo.local hpc-local" | sudo tee -a /etc/hosts

echo "System update and basic configuration completed."
