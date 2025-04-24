#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Run tests in the Docker environment
set -e

echo "==== Starting HPC Bursting Demo Containerized Tests ===="

# Check Slurm status
echo "Checking Slurm status..."
sinfo

# Check local nodes
echo "Checking local nodes..."
scontrol show nodes

# Verify NFS mounts
echo "Verifying NFS mounts..."
df -h | grep -E '(home|apps|scratch)'

# Test AWS connectivity (using LocalStack)
echo "Testing AWS connectivity..."
if [ -n "$MOCK_AWS_ENDPOINT" ]; then
  aws --endpoint-url=$MOCK_AWS_ENDPOINT ec2 describe-vpcs
else
  aws ec2 describe-vpcs
fi

# Test AWS resource creation
echo "Testing AWS resource creation..."
cd /app/scripts/aws
TEST_MODE=true ./01_create_iam_user.sh --test-mode

# Test setup script
echo "Testing full setup script in test mode..."
TEST_MODE=true ./setup_aws_infra.sh --test-mode

# Verify that resource files were created
echo "Verifying resource files..."
if [ -f "../aws-resources.txt" ]; then
  echo "Resource file created successfully"
  cat ../aws-resources.txt
else
  echo "Resource file not created"
  exit 1
fi

# Test AWS plugin configuration
echo "Testing Slurm AWS plugin..."
TEST_MODE=true ./06_configure_slurm_aws_plugin.sh --test-mode

# Test job submission with cloud bursting
echo "Testing job submission with cloud bursting..."
cd /app
cat > test-job.sh << EOF
#!/bin/bash
#SBATCH --job-name=test-job
#SBATCH --output=test-job.out
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:05:00
#SBATCH --partition=cloud
#SBATCH --constraint=cloud,cpu

echo "Running test job on \$(hostname) at \$(date)"
sleep 30
echo "Job completed at \$(date)"
EOF
chmod +x test-job.sh

# Submit the job
echo "Submitting test job..."
sbatch test-job.sh

# Show job queue
echo "Showing job queue..."
squeue

# Wait for job to complete (with timeout)
echo "Waiting for job to complete..."
timeout=120
counter=0
while squeue | grep -q test-job; do
  if [ $counter -ge $timeout ]; then
    echo "Timeout waiting for job to complete"
    break
  fi
  echo "Job still running... ($counter/$timeout seconds)"
  sleep 5
  ((counter+=5))
done

# Check job output
echo "Checking job output..."
if [ -f "test-job.out" ]; then
  cat test-job.out
else
  echo "Job output file not found"
fi

# Test resource cleanup
echo "Testing resource cleanup..."
cd /app/scripts/aws
TEST_MODE=true ./cleanup_aws_resources.sh --force --test-mode

echo "==== All containerized tests completed! ===="