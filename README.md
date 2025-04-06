# HPC Bursting Demo: Local to AWS

This repository contains scripts and configuration for creating a hybrid HPC environment that bursts from a local machine to AWS when needed.

## Overview

This project demonstrates how to set up an on-premises HPC environment with the capability to burst to the AWS cloud when demand exceeds local capacity. It includes:

- Local HPC system with Slurm, LDAP, and NFS
- AWS infrastructure with VPC, bastion host, and Route 53
- WireGuard VPN tunnel for secure connectivity
- Slurm AWS Plugin for cloud bursting
- Support for CPU and GPU workloads

## Architecture

```mermaid
graph TB
    subgraph "On-Premises"
        slurm["Slurm Controller"]
        ldap["LDAP Server"]
        nfs["NFS Server"]
        wg1["WireGuard Endpoint"]
        
        slurm --- nfs
        slurm --- ldap
        slurm --- wg1
    end
    
    subgraph "AWS Cloud"
        subgraph "VPC"
            subgraph "Public Subnet"
                bastion["Bastion Host"]
                wg2["WireGuard Endpoint"]
                bastion --- wg2
            end
            
            subgraph "Private Subnet"
                node1["Compute Node 1"]
                node2["Compute Node 2"]
                nodeN["Compute Node N"]
                gpu1["GPU Node 1"]
                gpu2["GPU Node 2"]
            end
            
            subgraph "AWS Services"
                r53["Route 53 Private Zone"]
                iam["IAM Roles & Policies"]
            end
            
            bastion --- node1
            bastion --- node2
            bastion --- nodeN
            bastion --- gpu1
            bastion --- gpu2
            bastion --- r53
            
            r53 -.- node1
            r53 -.- node2
            r53 -.- nodeN
            r53 -.- gpu1
            r53 -.- gpu2
        end
    end
    
    wg1 ===|"Secure Tunnel"| wg2
    
    slurm -->|"Launch Requests"| iam
    iam -->|"EC2 API"| node1
    iam -->|"EC2 API"| node2
    iam -->|"EC2 API"| nodeN
    iam -->|"EC2 API"| gpu1
    iam -->|"EC2 API"| gpu2
    
    node1 -.->|"Mount NFS"| nfs
    node2 -.->|"Mount NFS"| nfs
    nodeN -.->|"Mount NFS"| nfs
    gpu1 -.->|"Mount NFS"| nfs
    gpu2 -.->|"Mount NFS"| nfs
    
    node1 -.->|"Authentication"| ldap
    node2 -.->|"Authentication"| ldap
    nodeN -.->|"Authentication"| ldap
    gpu1 -.->|"Authentication"| ldap
    gpu2 -.->|"Authentication"| ldap
```

## Prerequisites

- Rocky Linux 9 VM with basic installation
- AWS account with appropriate permissions
- Internet connectivity for the VM

## Repository Structure

- `scripts/` - Setup scripts for local and AWS systems
- `config/` - Configuration templates
- `examples/` - Example jobs and workflows
- `docs/` - Documentation and guides
- `ansible/` - Ansible playbooks for automated deployment

## Getting Started

See the [Installation Guide](docs/installation.md) for detailed setup instructions.

## CloudFormation Deployment

For AWS-native deployment, you can use the included CloudFormation template with the AMIs created in the previous steps:

### Prerequisites
- Complete the AMI creation steps (running `setup_aws_infra.sh` or at least the `04_create_amis.sh` script)
- AWS CLI configured with appropriate permissions

### Deployment Steps

1. Generate CloudFormation parameters file from your created AMIs:
```bash
cd scripts/aws
./create_cf_parameters.sh
```
2. Deploy the CloudFormation stack:

```bash
aws cloudformation create-stack \
  --stack-name hpc-bursting-demo \
  --template-body file://../../cloudformation/hpc-bursting-infrastructure.yaml \
  --parameters file://../../cloudformation/ami-parameters.json \
  --capabilities CAPABILITY_IAM \
  --region us-west-2
```
3. Monitor stack creation:

```bash
aws cloudformation describe-stacks --stack-name hpc-bursting-demo
```
4. Once the stack is complete, retrieve the outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name hpc-bursting-demo \
  --query 'Stacks[0].Outputs' \
  --output table
```
5. Update your local WireGuard configuration with the bastion host's public IP:

```bash
BASTION_PUBLIC_IP=$(aws cloudformation describe-stacks \
  --stack-name hpc-bursting-demo \
  --query 'Stacks[0].Outputs[?OutputKey==`BastionPublicIP`].OutputValue' \
  --output text)

# Get the bastion's WireGuard public key
BASTION_PUBLIC_KEY=$(ssh -i hpc-demo-key.pem rocky@$BASTION_PUBLIC_IP "cat /etc/wireguard/publickey")

# Update your local WireGuard configuration
cat << WIREGUARD | sudo tee -a /etc/wireguard/wg0.conf
[Peer]
PublicKey = $BASTION_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32, 10.1.0.0/16
Endpoint = $BASTION_PUBLIC_IP:51820
PersistentKeepalive = 25
WIREGUARD

sudo systemctl restart wg-quick@wg0
```
6. Update the Slurm AWS plugin configuration with the CloudFormation outputs:

```bash
cd scripts/aws
./update_slurm_from_cloudformation.sh hpc-bursting-demo
```

7. Clean Up

   To delete the CloudFormation stack when you're done:

```bash
aws cloudformation delete-stack --stack-name hpc-bursting-demo
```
This provides a clean approach to integrating your existing AMI creation script with CloudFormation, and gives users clear instructions on how to use the CloudFormation-based deployment method.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 

