#!/bin/bash
# Slurm setup script
set -e

# Part 1: Install MariaDB and prepare database
echo "Installing and configuring MariaDB..."
sudo dnf install -y mariadb-server
sudo systemctl enable --now mariadb

echo "Creating Slurm database..."
sudo mysql -e "CREATE DATABASE slurm_acct_db;"
sudo mysql -e "CREATE USER 'slurm'@'localhost' IDENTIFIED BY 'slurm123';"
sudo mysql -e "GRANT ALL ON slurm_acct_db.* TO 'slurm'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Part 2: Set up Munge authentication
echo "Setting up Munge authentication..."
sudo dnf install -y munge munge-libs munge-devel

# Create directory for the override configuration
sudo mkdir -p /etc/systemd/system/munge.service.d

# Create override configuration to use key in shared location
sudo tee /etc/systemd/system/munge.service.d/override.conf > /dev/null << 'MUNGE'
[Service]
ExecStart=
ExecStart=/usr/sbin/munged --key-file=/export/slurm/munge.key
MUNGE

# Generate munge key and place it in the shared location
echo "Generating Munge key..."
sudo mkdir -p /export/slurm
sudo dd if=/dev/urandom bs=1 count=1024 > /tmp/munge.key
sudo mv /tmp/munge.key /export/slurm/munge.key
sudo chown munge:munge /export/slurm/munge.key
sudo chmod 400 /export/slurm/munge.key

# Reload systemd and start munge
echo "Starting Munge service..."
sudo systemctl daemon-reload
sudo systemctl enable --now munge

# Test munge
munge -n | unmunge

# Part 3: Install and configure Slurm
echo "Installing Slurm packages..."
# Enable CRB repository for development packages
sudo dnf config-manager --set-enabled crb
sudo dnf install -y epel-release
sudo dnf install -y slurm slurm-devel slurm-perlapi slurm-slurmctld slurm-slurmd slurm-slurmdbd
# Create necessary directories
echo "Creating Slurm directories..."
sudo mkdir -p /var/spool/slurm
sudo mkdir -p /var/log/slurm
sudo chown slurm:slurm /var/spool/slurm /var/log/slurm
sudo chmod 750 /var/log/slurm

# Create slurmdbd.conf
echo "Creating slurmdbd.conf..."
cat << SLURMDBD | sudo tee /etc/slurm/slurmdbd.conf
AuthType=auth/munge
DbdHost=localhost
DbdPort=6819
SlurmUser=slurm
DebugLevel=4
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/var/run/slurmdbd.pid
StorageType=accounting_storage/mysql
StorageHost=localhost
StorageUser=slurm
StoragePass=slurm123
StorageLoc=slurm_acct_db
SLURMDBD

# Set permissions on slurmdbd.conf
sudo chmod 600 /etc/slurm/slurmdbd.conf
sudo chown slurm:slurm /etc/slurm/slurmdbd.conf

# Create slurm.conf
echo "Creating slurm.conf..."
cat << SLURMCONF | sudo tee /etc/slurm/slurm.conf
# General Slurm configuration
ClusterName=demo-cluster
SlurmctldHost=controller.hpc-demo.internal

# Authentication and security
AuthType=auth/munge
CryptoType=crypto/munge
MpiDefault=pmix

# Process tracking and accounting
ProctrackType=proctrack/linuxproc
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=controller.hpc-demo.internal
JobAcctGatherType=jobacct_gather/linux

# Debugging options
SlurmctldDebug=info
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=/var/log/slurm/slurmd.log

# Scheduling
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core

# AWS Cloud Bursting Plugin
PrivateData=cloud
TreeWidth=65533

# Node configuration (local)
NodeName=hpc-local CPUs=2 RealMemory=2000 State=UNKNOWN
PartitionName=local Nodes=hpc-local Default=YES MaxTime=INFINITE State=UP

# AWS Cloud Bursting
SuspendProgram=/usr/sbin/slurm-aws-shutdown.sh
ResumeProgram=/usr/sbin/slurm-aws-resume.sh
SuspendTime=300
SuspendTimeout=300
ResumeTimeout=300
ResumeRate=0
SuspendRate=0

# Include AWS nodes definition
Include /etc/slurm/aws-nodes.conf
SLURMCONF

# Create initial AWS nodes configuration file
echo "Creating initial aws-nodes.conf..."
cat << AWSNODES | sudo tee /etc/slurm/aws-nodes.conf
# AWS Cloud Nodes - will be populated by the Slurm AWS plugin
NodeName=aws-[1-10] CPUs=4 RealMemory=7500 State=CLOUD
PartitionName=cloud Nodes=aws-[1-10] Default=NO MaxTime=INFINITE State=UP
AWSNODES

# Copy configurations to shared location
echo "Copying configurations to shared location..."
sudo cp /etc/slurm/slurm.conf /export/slurm/
sudo cp /etc/slurm/aws-nodes.conf /export/slurm/
# Start Slurm services
echo "Starting Slurm services..."
sudo systemctl enable --now slurmdbd
sleep 5
sudo systemctl enable --now slurmctld
sudo systemctl enable --now slurmd

# Configure Slurm accounting
echo "Configuring Slurm accounting..."
sudo sacctmgr -i add cluster demo-cluster
sudo sacctmgr -i add account demo-account description="Demo Account" organization="Demo Org"
sudo sacctmgr -i add user slurm account=demo-account adminlevel=Admin

# Create QoS with limits
sudo sacctmgr -i add qos normal
sudo sacctmgr -i add qos cloud GraceTime=120 MaxTRESPerUser=cpu=48 MaxJobsPerUser=8 MaxWall=24:00:00

# Add entry to /etc/hosts for Slurm controller
echo "10.0.0.1 controller.hpc-demo.internal nfs.hpc-demo.internal" | sudo tee -a /etc/hosts

# Check Slurm status
echo "Verifying Slurm status..."
sinfo

echo "Slurm setup completed."
