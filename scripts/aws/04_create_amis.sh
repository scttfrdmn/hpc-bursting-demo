#!/bin/bash
# Create AMIs for compute nodes
set -e

# Load resource IDs
source ../aws-resources.txt

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

# ARM CPU instances
c6g.large,2,4000,0.068,0,arm64
c6g.2xlarge,8,16000,0.272,0,arm64
c6g.4xlarge,16,32000,0.544,0,arm64
c6g.8xlarge,32,64000,1.088,0,arm64

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
if [ "$ARCH" == "arm64" ]; then
    AMI_BUILDER_INSTANCE="c6g.large"
    GPU_AMI_BUILDER_INSTANCE="g5g.xlarge"
    HAS_INFERENTIA="false"
    HAS_TRAINIUM="false"
else
    AMI_BUILDER_INSTANCE="c5.large"
    GPU_AMI_BUILDER_INSTANCE="g4dn.xlarge"
    HAS_INFERENTIA="true"
    HAS_TRAINIUM="true"
    INFERENTIA_AMI_BUILDER_INSTANCE="inf1.xlarge"
    TRAINIUM_AMI_BUILDER_INSTANCE="trn1.2xlarge"
fi

echo "Using architecture: $ARCH"
echo "CPU instance type: $AMI_BUILDER_INSTANCE"
echo "GPU instance type: $GPU_AMI_BUILDER_INSTANCE"

# Create function to build AMIs
create_ami() {
    local instance_type=$1
    local ami_suffix=$2
    local userdata_file=$3
    
    echo "Creating $ami_suffix AMI using $instance_type instance..."
    
    # Base AMI selection
    if [[ "$instance_type" == *"g"* && "$ARCH" == "x86_64" ]]; then
        # Use deep learning AMI for x86_64 GPU instances
        echo "Using Deep Learning AMI for x86_64 GPU..."
        BASE_AMI_ID=$(aws ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=Deep Learning Base AMI (Amazon Linux 2) Version*" \
                      "Name=architecture,Values=x86_64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    elif [[ "$instance_type" == *"g"* && "$ARCH" == "arm64" ]]; then
        # Use deep learning AMI for ARM GPU instances
        echo "Using Deep Learning AMI for ARM64 GPU..."
        BASE_AMI_ID=$(aws ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=Deep Learning Base AMI (Amazon Linux 2) Version*" \
                      "Name=architecture,Values=arm64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    elif [[ "$instance_type" == inf* ]]; then
        # Use Inferentia AMI
        echo "Using Inferentia AMI..."
        BASE_AMI_ID=$(aws ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=AWS Deep Learning Base AMI (Amazon Linux 2)*Neuron*" \
                      "Name=architecture,Values=x86_64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    elif [[ "$instance_type" == trn* ]]; then
        # Use Trainium AMI
        echo "Using Trainium AMI..."
        BASE_AMI_ID=$(aws ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=AWS Deep Learning Base AMI (Amazon Linux 2)*Neuron*" \
                      "Name=architecture,Values=x86_64" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    else
        # Use standard Rocky Linux AMI
        echo "Using standard Rocky Linux AMI..."
        BASE_AMI_ID=$(aws ec2 describe-images \
            --owners 679593333241 \
            --filters "Name=name,Values=Rocky-9-${ARCH}*" "Name=state,Values=available" \
            --query "sort_by(Images, &CreationDate)[-1].ImageId" \
            --output text \
            --region $AWS_REGION)
    fi
    
    echo "Using base AMI: $BASE_AMI_ID"

    # Launch instance to create AMI
    echo "Launching instance to create AMI..."
    INSTANCE_ID=$(aws ec2 run-instances \
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
    aws ec2 wait instance-running \
        --instance-ids $INSTANCE_ID \
        --region $AWS_REGION

    # Wait for instance to complete setup (about 10 minutes)
    echo "Waiting for AMI setup to complete (10 minutes)..."
    sleep 600

    # Create AMI
    echo "Creating AMI from instance..."
    AMI_NAME="hpc-demo-compute-$ami_suffix-$(date +%Y%m%d-%H%M%S)"
    AMI_ID=$(aws ec2 create-image \
        --instance-id $INSTANCE_ID \
        --name $AMI_NAME \
        --description "HPC Demo Compute Node AMI for $ami_suffix" \
        --region $AWS_REGION \
        --query 'ImageId' \
        --output text)

    echo "Created AMI: $AMI_ID"

    # Wait for the AMI to be available
    echo "Waiting for AMI to be available..."
    aws ec2 wait image-available \
        --image-ids $AMI_ID \
        --region $AWS_REGION

    # Terminate the instance
    echo "Terminating AMI builder instance..."
    aws ec2 terminate-instances \
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
cat << EOF > /usr/lib/systemd/system/slurm-node-startup.service
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

# Same base setup as CPU script
# ...

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

# Now create the AMIs
echo "Creating CPU AMI..."
CPU_AMI_ID=$(create_ami "$AMI_BUILDER_INSTANCE" "cpu" "cpu-userdata.sh")
echo "CPU AMI ID: $CPU_AMI_ID"

echo "Creating GPU AMI..."
GPU_AMI_ID=$(create_ami "$GPU_AMI_BUILDER_INSTANCE" "gpu" "gpu-userdata.sh")
echo "GPU AMI ID: $GPU_AMI_ID"

# Create Inferentia and Trainium AMIs if on x86_64
if [ "$HAS_INFERENTIA" == "true" ]; then
    echo "Creating Inferentia AMI..."
    INFERENTIA_AMI_ID=$(create_ami "$INFERENTIA_AMI_BUILDER_INSTANCE" "inferentia" "cpu-userdata.sh")
    echo "Inferentia AMI ID: $INFERENTIA_AMI_ID"
else
    INFERENTIA_AMI_ID="n/a"
fi

if [ "$HAS_TRAINIUM" == "true" ]; then
    echo "Creating Trainium AMI..."
    TRAINIUM_AMI_ID=$(create_ami "$TRAINIUM_AMI_BUILDER_INSTANCE" "trainium" "cpu-userdata.sh")
    echo "Trainium AMI ID: $TRAINIUM_AMI_ID"
else
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
