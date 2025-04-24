# HPC Bursting Demo: Local VM to AWS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/Tests-Passing-green.svg)](https://github.com/scttfrdmn/hpc-bursting-demo/actions)
[![AWS](https://img.shields.io/badge/AWS-Compatible-orange.svg)](https://aws.amazon.com/)
[![Slurm](https://img.shields.io/badge/Slurm-Integrated-blue.svg)](https://slurm.schedmd.com/)
[![Documentation](https://img.shields.io/badge/Docs-Available-brightgreen.svg)](https://github.com/scttfrdmn/hpc-bursting-demo/tree/main/docs)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Integrated-brightgreen.svg)](https://www.shellcheck.net/)
[![Status](https://img.shields.io/badge/Status-Beta-yellow.svg)](https://github.com/scttfrdmn/hpc-bursting-demo)
[![Platform](https://img.shields.io/badge/Platform-Rocky_Linux-lightgrey.svg)](https://rockylinux.org/)

A comprehensive solution for creating a hybrid HPC environment that bursts from a local virtual machine to AWS cloud resources.

## Overview

This project demonstrates how to set up an "on-premises" HPC environment with the capability to burst to the AWS cloud when compute demand exceeds local capacity.

### Key Features

- **On-Premises Components**: Slurm, LDAP, and NFS on a single VM
- **Secure Connectivity**: WireGuard VPN tunnel between on-premises and AWS
- **Dynamic Cloud Resources**: Automatically provision and terminate AWS instances
- **Cost Control**: Only pay for cloud resources when you need them
- **Flexible Workloads**: Support for both CPU and GPU compute jobs

## Architecture

<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <!-- SVG Architecture Diagram (preserved from original) -->
  <!-- On-Premises Environment -->
  <rect x="50" y="50" width="300" height="200" rx="10" fill="#f5f5f5" stroke="#000" />
  <text x="200" y="70" font-family="Arial" text-anchor="middle" font-weight="bold">On-Premises</text>
  
  <!-- On-Premises Components -->
  <rect x="80" y="90" width="100" height="40" rx="5" fill="#b3e0ff" stroke="#000" />
  <text x="130" y="115" font-family="Arial" text-anchor="middle" font-size="12">Slurm Controller</text>
  
  <rect x="80" y="150" width="100" height="40" rx="5" fill="#c2f0c2" stroke="#000" />
  <text x="130" y="175" font-family="Arial" text-anchor="middle" font-size="12">LDAP Server</text>
  
  <rect x="210" y="90" width="100" height="40" rx="5" fill="#ffcc99" stroke="#000" />
  <text x="260" y="115" font-family="Arial" text-anchor="middle" font-size="12">NFS Server</text>
  
  <rect x="210" y="150" width="100" height="40" rx="5" fill="#d9b3ff" stroke="#000" />
  <text x="260" y="175" font-family="Arial" text-anchor="middle" font-size="12">WireGuard</text>
  
  <!-- On-Premises Connections -->
  <line x1="130" y1="130" x2="130" y2="150" stroke="#000" />
  <line x1="180" y1="110" x2="210" y2="110" stroke="#000" />
  <line x1="180" y1="170" x2="210" y2="170" stroke="#000" />
  
  <!-- AWS Cloud Environment -->
  <rect x="450" y="50" width="300" height="450" rx="10" fill="#f5f5f5" stroke="#000" />
  <text x="600" y="70" font-family="Arial" text-anchor="middle" font-weight="bold">AWS Cloud</text>
  
  <!-- Public Subnet -->
  <rect x="470" y="90" width="260" height="100" rx="5" fill="#e6f7ff" stroke="#000" />
  <text x="600" y="105" font-family="Arial" text-anchor="middle" font-size="12">Public Subnet</text>
  
  <rect x="490" y="120" width="100" height="40" rx="5" fill="#b3e0ff" stroke="#000" />
  <text x="540" y="145" font-family="Arial" text-anchor="middle" font-size="12">Bastion Host</text>
  
  <rect x="610" y="120" width="100" height="40" rx="5" fill="#d9b3ff" stroke="#000" />
  <text x="660" y="145" font-family="Arial" text-anchor="middle" font-size="12">WireGuard</text>
  
  <!-- Private Subnet -->
  <rect x="470" y="210" width="260" height="160" rx="5" fill="#e6ffe6" stroke="#000" />
  <text x="600" y="225" font-family="Arial" text-anchor="middle" font-size="12">Private Subnet</text>
  
  <rect x="490" y="240" width="100" height="40" rx="5" fill="#ffffcc" stroke="#000" />
  <text x="540" y="265" font-family="Arial" text-anchor="middle" font-size="12">Compute Node</text>
  
  <rect x="610" y="240" width="100" height="40" rx="5" fill="#ffffcc" stroke="#000" />
  <text x="660" y="265" font-family="Arial" text-anchor="middle" font-size="12">Compute Node</text>
  
  <rect x="550" y="300" width="100" height="40" rx="5" fill="#ffd6cc" stroke="#000" />
  <text x="600" y="325" font-family="Arial" text-anchor="middle" font-size="12">GPU Node</text>
  
  <!-- AWS Services -->
  <rect x="470" y="390" width="260" height="90" rx="5" fill="#ffe6e6" stroke="#000" />
  <text x="600" y="405" font-family="Arial" text-anchor="middle" font-size="12">AWS Services</text>
  
  <rect x="490" y="420" width="100" height="40" rx="5" fill="#ffcccc" stroke="#000" />
  <text x="540" y="445" font-family="Arial" text-anchor="middle" font-size="12">Route 53</text>
  
  <rect x="610" y="420" width="100" height="40" rx="5" fill="#ffcccc" stroke="#000" />
  <text x="660" y="445" font-family="Arial" text-anchor="middle" font-size="12">IAM</text>
  
  <!-- Cross-Environment Connection -->
  <path d="M 310 170 Q 380 170 380 310 Q 380 450 450 450" stroke="#000" stroke-width="2" stroke-dasharray="5,5" fill="none" />
  <text x="380" y="280" font-family="Arial" text-anchor="middle" font-size="10" transform="rotate(90 380 280)">Secure Tunnel</text>
  
  <!-- AWS Internal Connections -->
  <line x1="590" y1="140" x2="610" y2="140" stroke="#000" />
  <line x1="540" y1="160" x2="540" y2="240" stroke="#000" />
  <line x1="660" y1="160" x2="660" y2="240" stroke="#000" />
  <line x1="540" y1="280" x2="540" y2="340" stroke="#000" stroke-dasharray="3,3" />
  <line x1="660" y1="280" x2="660" y2="340" stroke="#000" stroke-dasharray="3,3" />
  <line x1="600" y1="340" x2="600" y2="420" stroke="#000" />
  
  <!-- Data Flow Lines -->
  <path d="M 130 200 Q 130 500 490 440" stroke="#000" stroke-width="1" stroke-dasharray="3,3" fill="none" />
  <text x="300" y="480" font-family="Arial" text-anchor="middle" font-size="10">Launch Requests</text>
  
  <path d="M 260 200 Q 260 550 550 340" stroke="#000" stroke-width="1" stroke-dasharray="3,3" fill="none" />
  <text x="400" y="520" font-family="Arial" text-anchor="middle" font-size="10">NFS/Authentication</text>
</svg>

## Quick Start

For rapid deployment, see the [Getting Started Guide](docs/getting-started.md).

## Documentation

- [**Getting Started**](docs/getting-started.md): Quick setup for evaluation
- [**Architecture**](docs/architecture.md): Detailed system design
- [**Installation**](docs/installation/README.md)
  - [Manual Installation](docs/installation/manual.md)
  - [Ansible Installation](docs/installation/ansible.md)
  - [CloudFormation Installation](docs/installation/cloudformation.md)
- [**Configuration**](docs/configuration.md): Customization options
- [**Troubleshooting**](docs/troubleshooting.md): Common issues and solutions

## Prerequisites

- Rocky Linux 9 VM with sudo privileges
- AWS account with permissions for VPC, EC2, IAM, Route53
- AWS CLI configured with appropriate credentials
- Internet connectivity for the VM

## Repository Structure

- `scripts/` - Setup scripts for local and AWS systems
- `ansible/` - Ansible playbook for automated deployment
- `cloudformation/` - CloudFormation template for AWS
- `docs/` - Documentation and guides
- `tests/` - Test framework and test cases

## Contributing

Contributions are welcome! Please see the [Contributing Guide](CONTRIBUTING.md) for details on how to contribute to this project, including:

- Setting up a development environment
- Testing guidelines and procedures
- Pull request process
- Coding standards

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.