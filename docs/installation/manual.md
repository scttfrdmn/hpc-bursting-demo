# Manual Installation Guide

This guide provides step-by-step instructions for manually setting up the HPC bursting demo.

> **Time Estimate**: ~45 minutes  
> **AWS Cost Estimate**: ~$1-2/hour when running compute instances

## Prerequisites

- Rocky Linux 9 VM (minimal install) with at least:
  - 2 CPU cores
  - 4 GB RAM
  - 20 GB disk space
- AWS account with permissions to create EC2, VPC, IAM resources
- AWS CLI installed and configured with appropriate permissions
- Git to clone this repository

## 1. Prepare the Local Environment

### Clone the Repository

```bash
git clone https://github.com/yourusername/hpc-bursting-demo.git
cd hpc-bursting-demo
```

### System Update and Basic Configuration

This step updates the system and installs basic utilities:

```bash
cd scripts/local
chmod +x 01_system_update.sh
./01_system_update.sh
```

This script:
- Updates all system packages
- Installs basic utilities (vim, wget, curl, etc.)
- Sets the hostname to `hpc-local.demo.local`
- Updates `/etc/hosts`

## 2. Set Up Local HPC Components

### NFS Server Setup

```bash
chmod +x 02_setup_nfs.sh
./02_setup_nfs.sh
```

This configures:
- NFS server with exports for `/export/home`, `/export/apps`, `/export/scratch`, etc.
- Appropriate permissions for shared directories

### LDAP Server Setup

```bash
chmod +x 03_setup_ldap.sh
./03_setup_ldap.sh
```

This configures:
- 389 Directory Server instance
- A test user account (`testuser`)
- SSSD for client authentication

### Slurm Setup

```bash
chmod +x 04_setup_slurm.sh
./04_setup_slurm.sh
```

This configures:
- MariaDB database for Slurm accounting
- Munge authentication
- Slurm controller, database daemon, and compute node daemon
- Basic partitions and QoS settings

### WireGuard Setup

```bash
chmod +x 05_setup_wireguard.sh
./05_setup_wireguard.sh
```

This configures:
- WireGuard VPN for secure communication with AWS
- IP forwarding
- Firewall rules
- Monitoring script for connection maintenance

## 3. Set Up AWS Infrastructure

Now we'll configure the AWS side of the environment:

### IAM User Creation

```bash
cd ../aws
chmod +x 01_create_iam_user.sh
./01_create_iam_user.sh
```

This creates:
- IAM user for Slurm AWS Plugin
- Policy with necessary EC2 permissions
- Access key for authentication

### VPC and Network Setup

```bash
chmod +x 02_setup_vpc.sh
./02_setup_vpc.sh
```

This creates:
- VPC with public and private subnets
- Internet gateway
- Route tables
- Security groups
- Route53 private hosted zone

### Bastion Host Setup

```bash
chmod +x 03_setup_bastion.sh
./03_setup_bastion.sh
```

This creates:
- Bastion host in the public subnet
- WireGuard configuration on the bastion
- Routes between on-premises and AWS
- Establishes the secure tunnel

### AMI Creation

The default AMI creation process now offers interactive options:

```bash
chmod +x 04_create_amis.sh
./04_create_amis.sh
```

This launches an interactive tool that will:
- Always create a CPU AMI for your architecture
- Optionally create GPU, Inferentia (x86_64), and Trainium (x86_64) AMIs
- Let you choose between full-sized or demo (smaller) instances

For quick testing with minimal cost:

```bash
./04_create_amis.sh --quick
```

This creates a CPU-only AMI using smaller, cheaper instance types (t3.medium for x86_64 or t4g.medium for ARM64).

For production deployments with all accelerators:

```bash
./04_create_amis.sh --all
```

For specific configurations:

```bash
# Create both CPU and GPU AMIs with smaller instances
./04_create_amis.sh --gpu --demo

# Create only CPU and Inferentia AMIs (x86_64 only)
./04_create_amis.sh --inferentia
```

### Launch Template Creation

```bash
chmod +x 05_create_launch_template.sh
./05_create_launch_template.sh
```

This creates:
- Launch templates for CPU and GPU instances
- Configures instance metadata
- Sets up security groups and tags

### Slurm AWS Plugin Configuration

```bash
chmod +x 06_configure_slurm_aws_plugin.sh
./06_configure_slurm_aws_plugin.sh
```

This configures:
- AWS Plugin for Slurm v2
- Partition and node definitions
- Resume and suspend programs
- Resource limits

## 4. Verify the Setup

Test the bursting capability:

```bash
cd ..
chmod +x test_bursting.sh
./test_bursting.sh
```

This will:
- Submit a job to the local partition
- Submit a job to the cloud partition
- Display the status of both jobs

## 5. Using the System

### Basic Slurm Commands

```bash
# View partitions and nodes
sinfo

# Submit a job to the local partition
sbatch --partition=local myjob.sh

# Submit a job to the cloud partition
sbatch --partition=cloud myjob.sh

# Check job status
squeue

# Cancel a job
scancel JOB_ID
```

### Monitoring AWS Costs

To monitor costs associated with bursting:

```bash
cd scripts
./monitor-aws-costs.sh
```

## 6. Cleaning Up

When you're done using the system, you can clean up AWS resources:

```bash
cd scripts/aws
./cleanup_aws_resources.sh
```

> **Note**: The cleanup script is designed to remove only AWS resources while preserving your local HPC configuration. This allows you to later redeploy just the AWS portion without reconfiguring the local environment. See the [Troubleshooting Guide](../troubleshooting.md#separation-between-local-and-aws-components) for more details on this separation.

## Troubleshooting

See the [Troubleshooting Guide](../troubleshooting.md) for help with common issues.

## Next Steps

- Learn how to [customize the configuration](../configuration.md)
- Explore the [architecture details](../architecture.md)
- Set up [CloudFormation deployment](cloudformation.md) for AWS-native management