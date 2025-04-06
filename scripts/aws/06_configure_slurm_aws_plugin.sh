#!/bin/bash
# Configure Slurm AWS Plugin Version 2
set -e

# Load resource IDs
source ../aws-resources.txt

# Install dependencies
echo "Installing dependencies for AWS Slurm Plugin v2..."
sudo dnf install -y python3-pip git
sudo pip3 install boto3 botocore

# Download AWS Plugin for Slurm version 2 from the plugin-v2 branch
echo "Downloading AWS Plugin for Slurm version 2..."
sudo mkdir -p /usr/local/slurm-aws
cd /usr/local/slurm-aws
sudo rm -rf aws-plugin-for-slurm # Remove any existing installation
sudo git clone -b plugin-v2 https://github.com/aws-samples/aws-plugin-for-slurm.git .

# Create plugin directory
sudo mkdir -p /etc/slurm/aws

# Copy the plugin files to the plugin directory
sudo cp common.py resume.py suspend.py change_state.py generate_conf.py /etc/slurm/aws/
sudo chmod +x /etc/slurm/aws/*.py

# Create config.json file as per documentation
echo "Creating config.json file..."
cat << EOFCONFIG | sudo tee /etc/slurm/aws/config.json
{
   "LogLevel": "INFO",
   "LogFileName": "/var/log/slurm/aws_plugin.log",
   "SlurmBinPath": "/usr/bin",
   "SlurmConf": {
      "PrivateData": "CLOUD",
      "ResumeProgram": "/etc/slurm/aws/resume.py",
      "SuspendProgram": "/etc/slurm/aws/suspend.py",
      "ResumeRate": 100,
      "SuspendRate": 100,
      "ResumeTimeout": 300,
      "SuspendTime": 350,
      "TreeWidth": 60000
   }
}
EOFCONFIG

# Create partitions.json file
echo "Creating partitions.json file..."
cat << EOFPARTITIONS | sudo tee /etc/slurm/aws/partitions.json
{
   "Partitions": [
      {
         "PartitionName": "cloud",
         "NodeGroups": [
            {
               "NodeGroupName": "cpu",
               "MaxNodes": 20,
               "Region": "$AWS_REGION",
               "SlurmSpecifications": {
                  "CPUs": "2",
                  "RealMemory": "3500",
                  "Weight": "1"
               },
               "PurchasingOption": "on-demand",
               "OnDemandOptions": {
                   "AllocationStrategy": "lowest-price"
               },
               "LaunchTemplateSpecification": {
                  "LaunchTemplateName": "hpc-demo-compute-cpu",
                  "Version": "\$Latest"
               },
               "LaunchTemplateOverrides": [
EOFPARTITIONS

# Add CPU instance types based on architecture
LOCAL_ARCH=$(uname -m)
if [ "$LOCAL_ARCH" == "aarch64" ]; then
    cat << EOFCPUARM | sudo tee -a /etc/slurm/aws/partitions.json
                  {
                     "InstanceType": "c6g.large"
                  },
                  {
                     "InstanceType": "c6g.xlarge"
                  }
EOFCPUARM
else
    cat << EOFCPUX86 | sudo tee -a /etc/slurm/aws/partitions.json
                  {
                     "InstanceType": "c5.large"
                  },
                  {
                     "InstanceType": "c5.xlarge"
                  }
EOFCPUX86
fi

# Continue with the rest of partitions.json
cat << EOFPARTITIONS2 | sudo tee -a /etc/slurm/aws/partitions.json
               ],
               "SubnetIds": [
                  "$PRIVATE_SUBNET_ID"
               ],
               "Tags": [
                  {
                     "Key": "Project",
                     "Value": "HPC-Bursting-Demo"
                  }
               ]
            }
EOFPARTITIONS2

# Add GPU node group if architecture supports it
if [ "$LOCAL_ARCH" == "aarch64" ] && [ -n "$GPU_LAUNCH_TEMPLATE_ID" ] && [ "$GPU_LAUNCH_TEMPLATE_ID" != "n/a" ]; then
    cat << EOFGPUARM | sudo tee -a /etc/slurm/aws/partitions.json
            ,
            {
               "NodeGroupName": "gpu",
               "MaxNodes": 10,
               "Region": "$AWS_REGION",
               "SlurmSpecifications": {
                  "CPUs": "4",
                  "RealMemory": "16000",
                  "Features": "gpu",
                  "Weight": "10"
               },
               "PurchasingOption": "on-demand",
               "OnDemandOptions": {
                   "AllocationStrategy": "lowest-price"
               },
               "LaunchTemplateSpecification": {
                  "LaunchTemplateName": "hpc-demo-compute-gpu",
                  "Version": "\$Latest"
               },
               "LaunchTemplateOverrides": [
                  {
                     "InstanceType": "g5g.xlarge"
                  },
                  {
                     "InstanceType": "g5g.2xlarge"
                  }
               ],
               "SubnetIds": [
                  "$PRIVATE_SUBNET_ID"
               ],
               "Tags": [
                  {
                     "Key": "Project",
                     "Value": "HPC-Bursting-Demo"
                  }
               ]
            }
EOFGPUARM
elif [ "$LOCAL_ARCH" == "x86_64" ] && [ -n "$GPU_LAUNCH_TEMPLATE_ID" ] && [ "$GPU_LAUNCH_TEMPLATE_ID" != "n/a" ]; then
    cat << EOFGPUX86 | sudo tee -a /etc/slurm/aws/partitions.json
            ,
            {
               "NodeGroupName": "gpu",
               "MaxNodes": 10,
               "Region": "$AWS_REGION",
               "SlurmSpecifications": {
                  "CPUs": "4",
                  "RealMemory": "16000",
                  "Features": "gpu",
                  "Gres": "gpu:1",
                  "Weight": "10"
               },
               "PurchasingOption": "on-demand",
               "OnDemandOptions": {
                   "AllocationStrategy": "lowest-price"
               },
               "LaunchTemplateSpecification": {
                  "LaunchTemplateName": "hpc-demo-compute-gpu",
                  "Version": "\$Latest"
               },
               "LaunchTemplateOverrides": [
                  {
                     "InstanceType": "g4dn.xlarge"
                  },
                  {
                     "InstanceType": "g4dn.2xlarge"
                  }
               ],
               "SubnetIds": [
                  "$PRIVATE_SUBNET_ID"
               ],
               "Tags": [
                  {
                     "Key": "Project",
                     "Value": "HPC-Bursting-Demo"
                  }
               ]
            }
EOFGPUX86
fi

# Add specialized instance groups if supported
if [ "$LOCAL_ARCH" == "x86_64" ] && [ -n "$INFERENTIA_LAUNCH_TEMPLATE_ID" ] && [ "$INFERENTIA_LAUNCH_TEMPLATE_ID" != "n/a" ]; then
    cat << EOFINF | sudo tee -a /etc/slurm/aws/partitions.json
            ,
            {
               "NodeGroupName": "inferentia",
               "MaxNodes": 5,
               "Region": "$AWS_REGION",
               "SlurmSpecifications": {
                  "CPUs": "4",
                  "RealMemory": "8000",
                  "Features": "inferentia",
                  "Gres": "inferentia:1",
                  "Weight": "20"
               },
               "PurchasingOption": "on-demand",
               "OnDemandOptions": {
                   "AllocationStrategy": "lowest-price"
               },
               "LaunchTemplateSpecification": {
                  "LaunchTemplateName": "hpc-demo-compute-inferentia",
                  "Version": "\$Latest"
               },
               "LaunchTemplateOverrides": [
                  {
                     "InstanceType": "inf1.xlarge"
                  }
               ],
               "SubnetIds": [
                  "$PRIVATE_SUBNET_ID"
               ],
               "Tags": [
                  {
                     "Key": "Project",
                     "Value": "HPC-Bursting-Demo"
                  }
               ]
            }
EOFINF
fi

if [ "$LOCAL_ARCH" == "x86_64" ] && [ -n "$TRAINIUM_LAUNCH_TEMPLATE_ID" ] && [ "$TRAINIUM_LAUNCH_TEMPLATE_ID" != "n/a" ]; then
    cat << EOFTRN | sudo tee -a /etc/slurm/aws/partitions.json
            ,
            {
               "NodeGroupName": "trainium",
               "MaxNodes": 5,
               "Region": "$AWS_REGION",
               "SlurmSpecifications": {
                  "CPUs": "8",
                  "RealMemory": "32000",
                  "Features": "trainium",
                  "Gres": "trainium:1",
                  "Weight": "30"
               },
               "PurchasingOption": "on-demand",
               "OnDemandOptions": {
                   "AllocationStrategy": "lowest-price"
               },
               "LaunchTemplateSpecification": {
                  "LaunchTemplateName": "hpc-demo-compute-trainium",
                  "Version": "\$Latest"
               },
               "LaunchTemplateOverrides": [
                  {
                     "InstanceType": "trn1.2xlarge"
                  }
               ],
               "SubnetIds": [
                  "$PRIVATE_SUBNET_ID"
               ],
               "Tags": [
                  {
                     "Key": "Project",
                     "Value": "HPC-Bursting-Demo"
                  }
               ]
            }
EOFTRN
fi

# Close the partitions.json file
cat << EOFEND | sudo tee -a /etc/slurm/aws/partitions.json
         ],
         "PartitionOptions": {
            "Default": "No",
            "MaxTime": "INFINITE",
            "State": "UP"
         }
      }
   ]
}
EOFEND

# Generate Slurm configuration
echo "Generating Slurm configuration..."
cd /etc/slurm/aws
sudo ./generate_conf.py

# Append the generated configuration to slurm.conf
sudo cp /etc/slurm/slurm.conf /etc/slurm/slurm.conf.bak
sudo cat /etc/slurm/aws/slurm.conf.aws >> /etc/slurm/slurm.conf

# Copy the updated configuration to shared location
sudo cp /etc/slurm/slurm.conf /export/slurm/

# Add cron job to run change_state.py every minute
echo "Setting up cron job for change_state.py..."
(sudo crontab -l 2>/dev/null; echo "* * * * * /etc/slurm/aws/change_state.py &>/dev/null") | sudo crontab -

# Restart Slurm controller
echo "Restarting Slurm controller..."
sudo systemctl restart slurmctld

echo "Slurm AWS Plugin v2 configuration completed successfully."
