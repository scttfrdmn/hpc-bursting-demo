# Installation Guide

This guide provides step-by-step instructions for setting up the HPC bursting demo.

## Prerequisites

- Rocky Linux 9 VM (minimal install)
- AWS account with permissions to create EC2, VPC, IAM resources
- AWS CLI installed and configured
- Git to clone this repository

## Local HPC System Setup

### 1. Clone the Repository

git clone https://github.com/yourusername/hpc-bursting-demo.git
cd hpc-bursting-demo

### 2. Using the Setup Scripts

The easiest way to set up the local HPC system is using our setup script:

```bash
cd scripts/local
chmod +x setup_local_hpc.sh
./setup_local_hpc.sh
```

### 3. Alternative: Manual Setup

If you prefer to set up components manually, follow the individual component scripts:

```bash
# Update system
./01_system_update.sh

# Set up NFS server
./02_setup_nfs.sh

# Set up LDAP server
./03_setup_ldap.sh

# Configure Slurm
./04_setup_slurm.sh

# Set up WireGuard
./05_setup_wireguard.sh
```

## AWS Infrastructure Setup

After setting up the local system, configure the AWS infrastructure:

```bash
cd ../aws
chmod +x setup_aws_infra.sh
./setup_aws_infra.sh
```

This will set up:

- VPC, subnets, and security groups
- IAM user for Slurm AWS Plugin
- Bastion host with WireGuard
- AMI for compute nodes
- Launch template

## Verifying Setup

Test the bursting capability:

```bash
./test_bursting.sh
```

This script will submit jobs to both local and cloud partitions.

## Architecture-Specific Notes

### ARM64 vs x86_64

The scripts detect your local architecture and configure the cloud environment to match. For:

- x86_64 systems: Will use x86_64 instances in AWS
- ARM64 systems: Will use Graviton-based instances in AWS

## Cleanup

To tear down AWS resources when done:

```bash
./cleanup_aws_resources.sh
```

## Troubleshooting

See [Troubleshooting Guide](troubleshooting.md) for common issues and solutions. 

