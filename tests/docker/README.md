# Containerized Testing for HPC Bursting Demo

This directory contains Docker-based testing environment for the HPC Bursting Demo project. It sets up a complete simulation of the HPC environment with a controller node, a compute node, and a LocalStack instance for AWS service emulation.

## Components

1. **HPC Controller Node**: Runs Slurm controller, NFS server, and simulates the head node of the HPC cluster
2. **HPC Compute Node**: Simulates a compute node in the HPC cluster, connecting to the controller
3. **LocalStack**: Provides AWS service emulation for testing cloud bursting functionality

## Network Setup

The containerized environment creates a dedicated network with static IP addresses:
- Controller: 172.28.0.2
- Compute Node: 172.28.0.3 
- LocalStack: 172.28.0.10

## Shared Storage

The environment includes shared storage volumes to simulate the NFS shares:
- /home (shared home directories)
- /apps (shared applications)
- /scratch (shared scratch space)

## Usage

Use the `manage-containers.sh` script to control the environment:

```bash
# Start the environment
./manage-containers.sh start

# Show container status
./manage-containers.sh status

# Execute commands in the controller container
./manage-containers.sh exec-control sinfo

# Execute commands in the compute container
./manage-containers.sh exec-compute hostname

# Run the test suite
./manage-containers.sh test

# Stop the environment
./manage-containers.sh stop

# Clean up everything (stop and remove volumes)
./manage-containers.sh clean
```

## Testing Workflow

The automated test suite (`run-tests.sh`) performs the following steps:

1. Verify Slurm configuration
2. Test NFS mounts between nodes
3. Test AWS connectivity to LocalStack
4. Test AWS resource creation with the `--test-mode` flag
5. Test full infrastructure setup script with LocalStack
6. Test Slurm AWS plugin configuration
7. Submit a test job to the cloud partition to test cloud bursting
8. Test AWS resource cleanup

## Manual Testing

To interact with the containers directly:

```bash
# Log into the controller node
./manage-containers.sh exec-control bash

# Check Slurm status
sinfo

# Submit a job to the cloud partition
sbatch --partition=cloud --constraint=cloud,cpu --wrap="hostname"

# Watch the job queue
squeue

# Log into the compute node
./manage-containers.sh exec-compute bash
```

## Notes

- The LocalStack instance is configured to emulate the AWS services needed for HPC bursting
- All AWS CLI commands automatically use the LocalStack endpoint in test mode
- The environment uses Rocky Linux 9, the same as the target production environment