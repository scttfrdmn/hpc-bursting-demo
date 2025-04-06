#!/bin/bash
# Test HPC bursting to AWS
set -e

# Function to log messages
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Testing HPC bursting setup..."

# Check if Slurm is running
log "Checking Slurm services..."
systemctl status slurmctld | grep "active (running)" && log "✓ Slurm controller is running" || log "✗ Slurm controller is not running"
systemctl status slurmd | grep "active (running)" && log "✓ Slurm node daemon is running" || log "✗ Slurm node daemon is not running"
systemctl status slurmdbd | grep "active (running)" && log "✓ Slurm database daemon is running" || log "✗ Slurm database daemon is not running"

# Check Slurm nodes
log "Checking Slurm nodes..."
sinfo
scontrol show nodes

# Check WireGuard connection
log "Checking WireGuard connection..."
sudo wg show
ping -c 3 10.0.0.2 && log "✓ Can ping AWS bastion" || log "✗ Cannot ping AWS bastion"

# Submit a test job to the local partition
log "Submitting a test job to the local partition..."
cat << EOT > test_local_job.sh
#!/bin/bash
#SBATCH --job-name=test_local
#SBATCH --partition=local
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=test_local_%j.out

hostname
sleep 10
date
EOT

chmod +x test_local_job.sh
sbatch test_local_job.sh
sleep 15
log "Local job output:"
cat test_local_*.out

# Submit a test job to the cloud partition
log "Submitting a test job to the cloud partition..."
cat << EOT > test_cloud_job.sh
#!/bin/bash
#SBATCH --job-name=test_cloud
#SBATCH --partition=cloud
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=test_cloud_%j.out

hostname
sleep 60
date
EOT

chmod +x test_cloud_job.sh
sbatch test_cloud_job.sh
log "Waiting for cloud job to start..."
sleep 30
log "Cloud nodes status:"
squeue
sinfo

log "Test completed. Check 'test_cloud_*.out' after the job completes to see the output from the AWS cloud node."
log "Note: The cloud job may take several minutes to start as AWS instances are being provisioned."
