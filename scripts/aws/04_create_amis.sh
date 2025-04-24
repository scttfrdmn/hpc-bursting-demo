#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Create AMIs for compute nodes
set -e

# Load resource IDs
source ../aws-resources.txt

# Default options
CREATE_CPU_AMI=true
CREATE_GPU_AMI=false
CREATE_INFERENTIA_AMI=false
CREATE_TRAINIUM_AMI=false
USE_DEMO_INSTANCES=false
USE_INTERACTIVE=true
TEST_MODE=false

# Check if running in test mode with LocalStack
if [ "${TEST_MODE:-false}" = "true" ]; then
  # Set AWS endpoint URL for LocalStack
  AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
  echo "Running in TEST MODE using LocalStack at $AWS_ENDPOINT_URL"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      CREATE_GPU_AMI=true
      CREATE_INFERENTIA_AMI=true
      CREATE_TRAINIUM_AMI=true
      shift
      ;;
    --gpu)
      CREATE_GPU_AMI=true
      shift
      ;;
    --inferentia)
      CREATE_INFERENTIA_AMI=true
      shift
      ;;
    --trainium)
      CREATE_TRAINIUM_AMI=true
      shift
      ;;
    --demo)
      USE_DEMO_INSTANCES=true
      shift
      ;;
    --quick|--non-interactive)
      USE_INTERACTIVE=false
      USE_DEMO_INSTANCES=true  # Quick mode defaults to demo instances for lower cost
      shift
      ;;
    --test-mode)
      TEST_MODE=true
      USE_DEMO_INSTANCES=true  # Test mode defaults to demo instances
      USE_INTERACTIVE=false    # Test mode defaults to non-interactive
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --all              Create all supported AMI types for the current architecture"
      echo "  --gpu              Create GPU AMI"
      echo "  --inferentia       Create Inferentia AMI (x86_64 only)"
      echo "  --trainium         Create Trainium AMI (x86_64 only)"
      echo "  --demo             Use smaller instance types for demo/testing purposes"
      echo "  --quick            Skip interactive prompts, use demo instances, CPU AMI only (unless specified)"
      echo "  --non-interactive  Same as --quick"
      echo "  --test-mode        Run in test mode using LocalStack for AWS service emulation"
      echo "  --help             Show this help message"
      echo ""
      echo "Example:"
      echo "  $0                 Interactive mode (default when run in terminal)"
      echo "  $0 --quick         Create CPU AMI only using demo instance, no prompts"
      echo "  $0 --all           Create all supported AMI types"
      echo "  $0 --gpu --demo    Create CPU and GPU AMIs using smaller instances"
      echo "  $0 --test-mode     Run using LocalStack for testing"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# Interactive mode if no arguments disabling it and script is run in a terminal
if [[ $USE_INTERACTIVE == "true" && -t 0 ]]; then
  echo "=============================================="
  echo "    HPC Bursting Demo - AMI Creation Tool     "
  echo "=============================================="
  echo ""
  echo "This tool will create AMIs for the HPC Bursting Demo."
  echo "By default, only the CPU AMI will be created."
  echo ""
  
  read -p "Create GPU AMI? (requires ~15 minutes additional build time) [y/N]: " GPU_RESPONSE
  if [[ "$GPU_RESPONSE" =~ ^[Yy] ]]; then
    CREATE_GPU_AMI=true
  fi
  
  # Only prompt for Inferentia and Trainium on x86_64
  if [[ "$(uname -m)" == "x86_64" ]]; then
    read -p "Create Inferentia AMI? (x86_64 only, requires ~15 minutes additional build time) [y/N]: " INF_RESPONSE
    if [[ "$INF_RESPONSE" =~ ^[Yy] ]]; then
      CREATE_INFERENTIA_AMI=true
    fi
    
    read -p "Create Trainium AMI? (x86_64 only, requires ~15 minutes additional build time) [y/N]: " TRN_RESPONSE
    if [[ "$TRN_RESPONSE" =~ ^[Yy] ]]; then
      CREATE_TRAINIUM_AMI=true
    fi
  fi
  
  read -p "Use smaller instance types for demo/testing? (lower cost, but slower builds) [y/N]: " DEMO_RESPONSE
  if [[ "$DEMO_RESPONSE" =~ ^[Yy] ]]; then
    USE_DEMO_INSTANCES=true
  fi
  
  echo ""
  echo "Selected options:"
  echo "- CPU AMI: Yes (always created)"
  echo "- GPU AMI: $([ "$CREATE_GPU_AMI" == "true" ] && echo "Yes" || echo "No")"
  
  if [[ "$(uname -m)" == "x86_64" ]]; then
    echo "- Inferentia AMI: $([ "$CREATE_INFERENTIA_AMI" == "true" ] && echo "Yes" || echo "No")"
    echo "- Trainium AMI: $([ "$CREATE_TRAINIUM_AMI" == "true" ] && echo "Yes" || echo "No")"
  fi
  
  echo "- Demo instances: $([ "$USE_DEMO_INSTANCES" == "true" ] && echo "Yes" || echo "No")"
  echo ""
  
  read -p "Continue with these settings? [Y/n]: " CONTINUE_RESPONSE
  if [[ "$CONTINUE_RESPONSE" =~ ^[Nn] ]]; then
    echo "Exiting."
    exit 0
  fi
  
  echo ""
fi

# Create instance types configuration
echo "Creating instance types configuration..."
cat << INSTANCETYPES > ../config/instance-types.conf
# CPU-only instances with cost in service units per hour
# Format: instance_type,cpus,memory_mb,cost_per_hour,gpus,arch

# x86_64 CPU instances
c5.large,2,4000,0.085,0,x86_64
c5.2xlarge,8,16000,0.34,0,x86_64
c5.4xlarge,16,32000,0.68,0,x86_64
c5.9xlarge,36,72000,1.53,0,x86_64
t3.micro,2,1024,0.0104,0,x86_64
t3.small,2,2048,0.0208,0,x86_64
t3.medium,2,4096,0.0416,0,x86_64

# ARM CPU instances
c6g.large,2,4000,0.068,0,arm64
c6g.2xlarge,8,16000,0.272,0,arm64
c6g.4xlarge,16,32000,0.544,0,arm64
c6g.8xlarge,32,64000,1.088,0,arm64
t4g.micro,2,1024,0.0084,0,arm64
t4g.small,2,2048,0.0168,0,arm64
t4g.medium,2,4096,0.0336,0,arm64

# x86_64 GPU instances
g4dn.xlarge,4,16000,0.526,1,x86_64
g4dn.2xlarge,8,32000,0.752,1,x86_64
g4dn.4xlarge,16,64000,1.204,1,x86_64

# ARM GPU instances
g5g.xlarge,4,16000,0.556,1,arm64
g5g.2xlarge,8,32000,0.892,1,arm64
g5g.4xlarge,16,64000,1.784,1,arm64

# Inferentia instances (x86_64 only)
inf1.xlarge,4,8000,0.368,1,x86_64
inf1.2xlarge,8,16000,0.736,1,x86_64

# Trainium instances (x86_64 only)
trn1.2xlarge,8,32000,1.343,1,x86_64
INSTANCETYPES

# Choose instance type based on architecture
if [ "$(uname -m)" == "aarch64" ]; then
    ARCH="arm64"
    
    if [ "$USE_DEMO_INSTANCES" == "true" ]; then
        AMI_BUILDER_INSTANCE="t4g.medium"
        GPU_AMI_BUILDER_INSTANCE="g5g.xlarge"  # No smaller GPU instances available for ARM
    else
        AMI_BUILDER_INSTANCE="c6g.large"
        GPU_AMI_BUILDER_INSTANCE="g5g.xlarge"
    fi
    
    HAS_INFERENTIA="false"
    HAS_TRAINIUM="false"
else
    ARCH="x86_64"
    
    if [ "$USE_DEMO_INSTANCES" == "true" ]; then
        AMI_BUILDER_INSTANCE="t3.medium"
        GPU_AMI_BUILDER_INSTANCE="g4dn.xlarge"  # No smaller GPU instances available
        INFERENTIA_AMI_BUILDER_INSTANCE="inf1.xlarge"  # No smaller Inferentia instances
        TRAINIUM_AMI_BUILDER_INSTANCE="trn1.2xlarge"  # No smaller Trainium instances
    else
        AMI_BUILDER_INSTANCE="c5.large"
        GPU_AMI_BUILDER_INSTANCE="g4dn.xlarge"
        INFERENTIA_AMI_BUILDER_INSTANCE="inf1.xlarge"
        TRAINIUM_AMI_BUILDER_INSTANCE="trn1.2xlarge"
    fi
    
    HAS_INFERENTIA="true"
    HAS_TRAINIUM="true"
fi

echo "Using architecture: $ARCH"
echo "CPU instance type: $AMI_BUILDER_INSTANCE"

if [ "$CREATE_GPU_AMI" == "true" ]; then
    echo "GPU instance type: $GPU_AMI_BUILDER_INSTANCE"
fi

if [ "$ARCH" == "x86_64" ]; then
    if [ "$CREATE_INFERENTIA_AMI" == "true" ]; then
        echo "Inferentia instance type: $INFERENTIA_AMI_BUILDER_INSTANCE"
    fi
    
    if [ "$CREATE_TRAINIUM_AMI" == "true" ]; then
        echo "Trainium instance type: $TRAINIUM_AMI_BUILDER_INSTANCE"
    fi
fi

# Helper function for AWS CLI commands with optional LocalStack endpoint
aws_cmd() {
    if [ "$TEST_MODE" = "true" ]; then
        aws --endpoint-url="$AWS_ENDPOINT_URL" "$@"
    else
        aws "$@"
    fi
}

# Create function to build AMIs
create_ami() {
    local instance_type=$1
    local ami_suffix=$2
    local userdata_file=$3
    
    echo "Creating $ami_suffix AMI using $instance_type instance..."
    
    # For test mode, use mock AMI IDs
    if [ "$TEST_MODE" = "true" ]; then
        # Use mock AMI IDs for testing
        echo "Test mode: Using mock AMI ID for $ami_suffix"
        if [[ "$instance_type" == *"g"* ]]; then
            BASE_AMI_ID="ami-gpu-mock-12345"
        elif [[ "$instance_type" == inf* ]]; then
            BASE_AMI_ID="ami-inf-mock-12345"
        elif [[ "$instance_type" == trn* ]]; then
            BASE_AMI_ID="ami-trn-mock-12345"
        else
            BASE_AMI_ID="ami-cpu-mock-12345"
        fi
        echo "Using mock base AMI: $BASE_AMI_ID"
    fi
    
    # Base AMI selection
    if [[ "$instance_type" == *"g"* && "$ARCH" == "x86_64" ]]; then
        # Use deep learning AMI for x86_64 GPU instances
        echo "Using Deep Learning AMI for x86_64 GPU..."
        BASE_AMI_ID=$(aws_cmd ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=Deep Learning Base AMI (Amazon Linux 2) Version*" \
                      "Name=architecture,Values=x86_64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    elif [[ "$instance_type" == *"g"* && "$ARCH" == "arm64" ]]; then
        # Use deep learning AMI for ARM GPU instances
        echo "Using Deep Learning AMI for ARM64 GPU..."
        BASE_AMI_ID=$(aws_cmd ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=Deep Learning Base AMI (Amazon Linux 2) Version*" \
                      "Name=architecture,Values=arm64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    elif [[ "$instance_type" == inf* ]]; then
        # Use Inferentia AMI
        echo "Using Inferentia AMI..."
        BASE_AMI_ID=$(aws_cmd ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=AWS Deep Learning Base AMI (Amazon Linux 2)*Neuron*" \
                      "Name=architecture,Values=x86_64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    elif [[ "$instance_type" == trn* ]]; then
        # Use Trainium AMI
        echo "Using Trainium AMI..."
        BASE_AMI_ID=$(aws_cmd ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=AWS Deep Learning Base AMI (Amazon Linux 2)*Neuron*" \
                      "Name=architecture,Values=x86_64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    else
        # Use standard Rocky Linux AMI
        echo "Using standard Rocky Linux AMI..."
        BASE_AMI_ID=$(aws_cmd ec2 describe-images \
            --owners 679593333241 \
            --filters "Name=name,Values=Rocky-9-${ARCH}*" "Name=state,Values=available" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    fi
    
    echo "Using base AMI: $BASE_AMI_ID"

    # Test mode: Skip instance creation, use mock AMI IDs
    if [ "$TEST_MODE" = "true" ]; then
        echo "Test mode: Skipping instance creation and AMI building"
        INSTANCE_ID="i-mock-instance-12345"
        echo "Mock instance ID: $INSTANCE_ID"
        
        # Generate a mock AMI ID based on the instance type
        if [[ "$instance_type" == *"g"* ]]; then
            AMI_ID="ami-$ami_suffix-gpu-12345"
        elif [[ "$instance_type" == inf* ]]; then
            AMI_ID="ami-$ami_suffix-inf-12345"
        elif [[ "$instance_type" == trn* ]]; then
            AMI_ID="ami-$ami_suffix-trn-12345"
        else
            AMI_ID="ami-$ami_suffix-cpu-12345"
        fi
        
        echo "Created mock AMI: $AMI_ID"
        echo "$AMI_ID"  # Echo the mock AMI ID so it gets captured by the caller
        return 0  # Return success
    fi

    # Launch instance to create AMI
    echo "Launching instance to create AMI..."
    INSTANCE_ID=$(aws_cmd ec2 run-instances \
        --image-id $BASE_AMI_ID \
        --instance-type $instance_type \
        --key-name hpc-demo-key \
        --security-group-ids $COMPUTE_SG_ID \
        --subnet-id $PRIVATE_SUBNET_ID \
        --user-data file://$userdata_file \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=hpc-demo-ami-builder},{Key=Project,Value=HPC-Bursting-Demo}]' \
        --region $AWS_REGION \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "Launched AMI builder instance: $INSTANCE_ID"

    # Wait for the instance to be running
    echo "Waiting for instance to be running..."
    aws_cmd ec2 wait instance-running \
        --instance-ids $INSTANCE_ID \
        --region $AWS_REGION

    # Wait for instance to complete setup (about 10 minutes)
    WAIT_TIME=600
    if [ "$USE_DEMO_INSTANCES" == "true" ]; then
        # Smaller instances may take longer to complete setup
        WAIT_TIME=900
    fi
    
    echo "Waiting for AMI setup to complete ($(($WAIT_TIME/60)) minutes)..."
    sleep $WAIT_TIME

    # Create AMI
    echo "Creating AMI from instance..."
    AMI_NAME="hpc-demo-compute-$ami_suffix-$(date +%Y%m%d-%H%M%S)"
    AMI_ID=$(aws_cmd ec2 create-image \
        --instance-id $INSTANCE_ID \
        --name $AMI_NAME \
        --description "HPC Demo Compute Node AMI for $ami_suffix" \
        --region $AWS_REGION \
        --query 'ImageId' \
        --output text)

    echo "Created AMI: $AMI_ID"

    # Wait for the AMI to be available
    echo "Waiting for AMI to be available..."
    aws_cmd ec2 wait image-available \
        --image-ids $AMI_ID \
        --region $AWS_REGION

    # Terminate the instance
    echo "Terminating AMI builder instance..."
    aws_cmd ec2 terminate-instances \
        --instance-ids $INSTANCE_ID \
        --region $AWS_REGION

    # Return the AMI ID
    echo $AMI_ID
}

# Create userdata scripts for different instance types
echo "Creating userdata scripts..."

# CPU userdata script
cat << 'CPUUSERDATA' > cpu-userdata.sh
#!/bin/bash
set -e

# Update system
dnf update -y

# Install required packages
dnf install -y nfs-utils munge vim wget curl git tar zip unzip
dnf install -y epel-release
dnf config-manager --set-enabled crb
dnf install -y slurm slurm-slurmd

# Create required directories
mkdir -p /etc/slurm
mkdir -p /var/spool/slurm
mkdir -p /var/log/slurm
mkdir -p /etc/munge

# Create directories for mounts
mkdir -p /home
mkdir -p /apps
mkdir -p /scratch

# Create Slurm user
groupadd -g 981 slurm || echo "Group slurm already exists"
useradd -u 981 -g slurm -s /bin/bash slurm || echo "User slurm already exists"
chown -R slurm:slurm /var/spool/slurm /var/log/slurm

# Create fstab entries with DNS names
cat << FSTABEOF >> /etc/fstab
nfs.hpc-demo.internal:/export/home    /home    nfs    defaults,_netdev    0 0
nfs.hpc-demo.internal:/export/apps    /apps    nfs    defaults,_netdev    0 0
nfs.hpc-demo.internal:/export/scratch /scratch nfs    defaults,_netdev    0 0
nfs.hpc-demo.internal:/export/slurm   /etc/slurm nfs  defaults,_netdev    0 0
FSTABEOF

# Create startup script
cat << 'STARTUPEOF' > /usr/local/bin/slurm-node-startup.sh
#!/bin/bash

# Mount NFS shares
mount -a

# Wait a bit for NFS to be mounted
sleep 5

# Copy munge key from shared location
cp /etc/slurm/munge.key /etc/munge/
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

# Start services
systemctl start munge
systemctl start slurmd

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Set hostname from Slurm configuration
NODE_NAME=$(scontrol show node | grep -i $PRIVATE_IP | awk '{print $1}' | cut -d= -f2)
if [ -n "$NODE_NAME" ]; then
    hostnamectl set-hostname $NODE_NAME.hpc-demo.internal
    echo "$PRIVATE_IP $NODE_NAME.hpc-demo.internal $NODE_NAME" >> /etc/hosts
fi

# Configure logging to head node
cat << RSYSLOGCONF > /etc/rsyslog.d/forward.conf
*.* @controller.hpc-demo.internal:514
RSYSLOGCONF
systemctl restart rsyslog

# Mark node as ready
scontrol update nodename=$NODE_NAME state=resume
STARTUPEOF

chmod +x /usr/local/bin/slurm-node-startup.sh

# Create systemd service for startup script
cat << SERVICE > /usr/lib/systemd/system/slurm-node-startup.service
[Unit]
Description=Slurm node startup configuration
After=network.target
Before=slurmd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/slurm-node-startup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

# Enable services
systemctl enable munge
systemctl enable slurm-node-startup
systemctl enable slurmd

# Install SSSD for LDAP authentication
dnf install -y sssd sssd-ldap oddjob-mkhomedir

# Configure SSSD with DNS name
cat << SSSD > /etc/sssd/sssd.conf
[sssd]
domains = demo.local
config_file_version = 2
services = nss, pam

[domain/demo.local]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://ldap.hpc-demo.internal
ldap_search_base = dc=demo,dc=local
ldap_user_search_base = ou=People,dc=demo,dc=local
ldap_group_search_base = ou=Groups,dc=demo,dc=local
ldap_id_use_start_tls = False
ldap_tls_reqcert = never
enumerate = True
cache_credentials = True

# Schema mappings
ldap_user_object_class = posixAccount
ldap_user_name = uid
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_user_home_directory = homeDirectory
ldap_user_shell = loginShell

ldap_group_object_class = posixGroup
ldap_group_name = cn
ldap_group_gid_number = gidNumber
ldap_group_member = memberUid
SSSD

chmod 600 /etc/sssd/sssd.conf
authselect select sssd with-mkhomedir --force

# Enable SSSD
systemctl enable sssd

# Install Spack dependencies
dnf install -y python3 python3-devel gcc gcc-c++ gcc-gfortran make patch file git which bzip2 xz unzip zlib-devel

# Create a script to setup Spack environment on login
cat << 'SPACK' > /etc/profile.d/spack.sh
#!/bin/bash
if [ -f /apps/spack/share/spack/setup-env.sh ]; then
    source /apps/spack/share/spack/setup-env.sh
fi
SPACK

chmod +x /etc/profile.d/spack.sh

# Clean up for AMI creation
dnf clean all
rm -rf /tmp/*
rm -f /root/.bash_history
find /var/log -type f -exec truncate --size=0 {} \;

# Signal completion
touch /tmp/ami-setup-complete
CPUUSERDATA

# GPU userdata script
cat << 'GPUUSERDATA' > gpu-userdata.sh
#!/bin/bash
set -e

# Update system
dnf update -y

# Install required packages
dnf install -y nfs-utils munge vim wget curl git tar zip unzip
dnf install -y epel-release
dnf config-manager --set-enabled crb
dnf install -y slurm slurm-slurmd

# Create required directories
mkdir -p /etc/slurm
mkdir -p /var/spool/slurm
mkdir -p /var/log/slurm
mkdir -p /etc/munge

# Create directories for mounts
mkdir -p /home
mkdir -p /apps
mkdir -p /scratch

# Create Slurm user
groupadd -g 981 slurm || echo "Group slurm already exists"
useradd -u 981 -g slurm -s /bin/bash slurm || echo "User slurm already exists"
chown -R slurm:slurm /var/spool/slurm /var/log/slurm

# Create fstab entries with DNS names
cat << FSTABEOF >> /etc/fstab
nfs.hpc-demo.internal:/export/home    /home    nfs    defaults,_netdev    0 0
nfs.hpc-demo.internal:/export/apps    /apps    nfs    defaults,_netdev    0 0
nfs.hpc-demo.internal:/export/scratch /scratch nfs    defaults,_netdev    0 0
nfs.hpc-demo.internal:/export/slurm   /etc/slurm nfs  defaults,_netdev    0 0
FSTABEOF

# Create startup script
cat << 'STARTUPEOF' > /usr/local/bin/slurm-node-startup.sh
#!/bin/bash

# Mount NFS shares
mount -a

# Wait a bit for NFS to be mounted
sleep 5

# Copy munge key from shared location
cp /etc/slurm/munge.key /etc/munge/
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

# Start services
systemctl start munge
systemctl start slurmd

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Set hostname from Slurm configuration
NODE_NAME=$(scontrol show node | grep -i $PRIVATE_IP | awk '{print $1}' | cut -d= -f2)
if [ -n "$NODE_NAME" ]; then
    hostnamectl set-hostname $NODE_NAME.hpc-demo.internal
    echo "$PRIVATE_IP $NODE_NAME.hpc-demo.internal $NODE_NAME" >> /etc/hosts
fi

# Configure logging to head node
cat << RSYSLOGCONF > /etc/rsyslog.d/forward.conf
*.* @controller.hpc-demo.internal:514
RSYSLOGCONF
systemctl restart rsyslog

# Mark node as ready
scontrol update nodename=$NODE_NAME state=resume
STARTUPEOF

chmod +x /usr/local/bin/slurm-node-startup.sh

# Create systemd service for startup script
cat << SERVICE > /usr/lib/systemd/system/slurm-node-startup.service
[Unit]
Description=Slurm node startup configuration
After=network.target
Before=slurmd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/slurm-node-startup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

# Enable services
systemctl enable munge
systemctl enable slurm-node-startup
systemctl enable slurmd

# Install SSSD for LDAP authentication
dnf install -y sssd sssd-ldap oddjob-mkhomedir

# Configure SSSD with DNS name
cat << SSSD > /etc/sssd/sssd.conf
[sssd]
domains = demo.local
config_file_version = 2
services = nss, pam

[domain/demo.local]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://ldap.hpc-demo.internal
ldap_search_base = dc=demo,dc=local
ldap_user_search_base = ou=People,dc=demo,dc=local
ldap_group_search_base = ou=Groups,dc=demo,dc=local
ldap_id_use_start_tls = False
ldap_tls_reqcert = never
enumerate = True
cache_credentials = True

# Schema mappings
ldap_user_object_class = posixAccount
ldap_user_name = uid
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_user_home_directory = homeDirectory
ldap_user_shell = loginShell

ldap_group_object_class = posixGroup
ldap_group_name = cn
ldap_group_gid_number = gidNumber
ldap_group_member = memberUid
SSSD

chmod 600 /etc/sssd/sssd.conf
authselect select sssd with-mkhomedir --force

# Enable SSSD
systemctl enable sssd

# Install Spack dependencies
dnf install -y python3 python3-devel gcc gcc-c++ gcc-gfortran make patch file git which bzip2 xz unzip zlib-devel

# Create a script to setup Spack environment on login
cat << 'SPACK' > /etc/profile.d/spack.sh
#!/bin/bash
if [ -f /apps/spack/share/spack/setup-env.sh ]; then
    source /apps/spack/share/spack/setup-env.sh
fi
SPACK

chmod +x /etc/profile.d/spack.sh

# Add GPU-specific configuration
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
echo "Detected instance type: $INSTANCE_TYPE"

# Configure GPU for Slurm
cat << GRESCONF > /etc/slurm/gres.conf
Name=gpu Type=nvidia File=/dev/nvidia0
GRESCONF

# Clean up for AMI creation
dnf clean all
rm -rf /tmp/*
rm -f /root/.bash_history
find /var/log -type f -exec truncate --size=0 {} \;

# Signal completion
touch /tmp/ami-setup-complete
GPUUSERDATA

# Create the AMIs based on user selections
echo "Creating CPU AMI..."
CPU_AMI_ID=$(create_ami "$AMI_BUILDER_INSTANCE" "cpu" "cpu-userdata.sh")
echo "CPU AMI ID: $CPU_AMI_ID"

# Create GPU AMI if selected
if [ "$CREATE_GPU_AMI" == "true" ]; then
    echo "Creating GPU AMI..."
    GPU_AMI_ID=$(create_ami "$GPU_AMI_BUILDER_INSTANCE" "gpu" "gpu-userdata.sh")
    echo "GPU AMI ID: $GPU_AMI_ID"
else
    GPU_AMI_ID="n/a"
fi

# Create Inferentia and Trainium AMIs if selected and on x86_64
if [ "$ARCH" == "x86_64" ]; then
    if [ "$CREATE_INFERENTIA_AMI" == "true" ] && [ "$HAS_INFERENTIA" == "true" ]; then
        echo "Creating Inferentia AMI..."
        INFERENTIA_AMI_ID=$(create_ami "$INFERENTIA_AMI_BUILDER_INSTANCE" "inferentia" "cpu-userdata.sh")
        echo "Inferentia AMI ID: $INFERENTIA_AMI_ID"
    else
        INFERENTIA_AMI_ID="n/a"
    fi
    
    if [ "$CREATE_TRAINIUM_AMI" == "true" ] && [ "$HAS_TRAINIUM" == "true" ]; then
        echo "Creating Trainium AMI..."
        TRAINIUM_AMI_ID=$(create_ami "$TRAINIUM_AMI_BUILDER_INSTANCE" "trainium" "cpu-userdata.sh")
        echo "Trainium AMI ID: $TRAINIUM_AMI_ID"
    else
        TRAINIUM_AMI_ID="n/a"
    fi
else
    INFERENTIA_AMI_ID="n/a"
    TRAINIUM_AMI_ID="n/a"
fi

# Update aws-resources.txt
cat << RESOURCES >> ../aws-resources.txt
CPU_AMI_ID=$CPU_AMI_ID
GPU_AMI_ID=$GPU_AMI_ID
INFERENTIA_AMI_ID=$INFERENTIA_AMI_ID
TRAINIUM_AMI_ID=$TRAINIUM_AMI_ID
RESOURCES

echo "AMI creation completed successfully."
echo ""
echo "Summary of created AMIs:"
echo "- CPU AMI ID: $CPU_AMI_ID"
echo "- GPU AMI ID: $GPU_AMI_ID"

if [ "$ARCH" == "x86_64" ]; then
    echo "- Inferentia AMI ID: $INFERENTIA_AMI_ID"
    echo "- Trainium AMI ID: $TRAINIUM_AMI_ID"
fi

echo ""
echo "These AMI IDs have been saved to ../aws-resources.txt"
echo "Proceed to the next step (05_create_launch_template.sh) to create launch templates."