#!/bin/bash
# Create launch templates for compute nodes
set -e

# Load resource IDs
source ../aws-resources.txt

# Create launch template for CPU compute nodes
echo "Creating launch template for CPU compute nodes..."
CPU_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name hpc-demo-compute-cpu \
    --version-description "Initial version" \
    --launch-template-data "{
        \"ImageId\": \"$CPU_AMI_ID\",
        \"InstanceType\": \"${AMI_BUILDER_INSTANCE}\",
        \"KeyName\": \"hpc-demo-key\",
        \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
        \"TagSpecifications\": [
            {
                \"ResourceType\": \"instance\",
                \"Tags\": [
                    {
                        \"Key\": \"Name\",
                        \"Value\": \"hpc-demo-compute\"
                    },
                    {
                        \"Key\": \"Project\",
                        \"Value\": \"HPC-Bursting-Demo\"
                    }
                ]
            }
        ],
        \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
# This is handled by the slurm-node-startup service
exit 0')\"
    }" \
    --region $AWS_REGION \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text)

echo "Created CPU launch template: $CPU_LAUNCH_TEMPLATE_ID"

# Create launch template for GPU compute nodes
echo "Creating launch template for GPU compute nodes..."
GPU_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name hpc-demo-compute-gpu \
    --version-description "Initial version" \
    --launch-template-data "{
        \"ImageId\": \"$GPU_AMI_ID\",
        \"InstanceType\": \"${GPU_AMI_BUILDER_INSTANCE}\",
        \"KeyName\": \"hpc-demo-key\",
        \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
        \"TagSpecifications\": [
            {
                \"ResourceType\": \"instance\",
                \"Tags\": [
                    {
                        \"Key\": \"Name\",
                        \"Value\": \"hpc-demo-compute-gpu\"
                    },
                    {
                        \"Key\": \"Project\",
                        \"Value\": \"HPC-Bursting-Demo\"
                    }
                ]
            }
        ],
        \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
# This is handled by the slurm-node-startup service
exit 0')\"
    }" \
    --region $AWS_REGION \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text)

echo "Created GPU launch template: $GPU_LAUNCH_TEMPLATE_ID"

# Create launch templates for specialized instances if available
if [ "$INFERENTIA_AMI_ID" != "n/a" ]; then
    echo "Creating launch template for Inferentia compute nodes..."
    INFERENTIA_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
        --launch-template-name hpc-demo-compute-inferentia \
        --version-description "Initial version" \
        --launch-template-data "{
            \"ImageId\": \"$INFERENTIA_AMI_ID\",
            \"InstanceType\": \"${INFERENTIA_AMI_BUILDER_INSTANCE}\",
            \"KeyName\": \"hpc-demo-key\",
            \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
            \"TagSpecifications\": [
                {
                    \"ResourceType\": \"instance\",
                    \"Tags\": [
                        {
                            \"Key\": \"Name\",
                            \"Value\": \"hpc-demo-compute-inferentia\"
                        },
                        {
                            \"Key\": \"Project\",
                            \"Value\": \"HPC-Bursting-Demo\"
                        }
                    ]
                }
            ],
            \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
    # This is handled by the slurm-node-startup service
    exit 0')\"
        }" \
        --region $AWS_REGION \
        --query 'LaunchTemplate.LaunchTemplateId' \
        --output text)
    
    echo "Created Inferentia launch template: $INFERENTIA_LAUNCH_TEMPLATE_ID"
else
    INFERENTIA_LAUNCH_TEMPLATE_ID="n/a"
fi

if [ "$TRAINIUM_AMI_ID" != "n/a" ]; then
    echo "Creating launch template for Trainium compute nodes..."
    TRAINIUM_LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
        --launch-template-name hpc-demo-compute-trainium \
        --version-description "Initial version" \
        --launch-template-data "{
            \"ImageId\": \"$TRAINIUM_AMI_ID\",
            \"InstanceType\": \"${TRAINIUM_AMI_BUILDER_INSTANCE}\",
            \"KeyName\": \"hpc-demo-key\",
            \"SecurityGroupIds\": [\"$COMPUTE_SG_ID\"],
            \"TagSpecifications\": [
                {
                    \"ResourceType\": \"instance\",
                    \"Tags\": [
                        {
                            \"Key\": \"Name\",
                            \"Value\": \"hpc-demo-compute-trainium\"
                        },
                        {
                            \"Key\": \"Project\",
                            \"Value\": \"HPC-Bursting-Demo\"
                        }
                    ]
                }
            ],
            \"UserData\": \"$(base64 -w 0 <<< '#!/bin/bash
    # This is handled by the slurm-node-startup service
    exit 0')\"
        }" \
        --region $AWS_REGION \
        --query 'LaunchTemplate.LaunchTemplateId' \
        --output text)
    
    echo "Created Trainium launch template: $TRAINIUM_LAUNCH_TEMPLATE_ID"
else
    TRAINIUM_LAUNCH_TEMPLATE_ID="n/a"
fi

# Update aws-resources.txt
cat << RESOURCES >> ../aws-resources.txt
CPU_LAUNCH_TEMPLATE_ID=$CPU_LAUNCH_TEMPLATE_ID
GPU_LAUNCH_TEMPLATE_ID=$GPU_LAUNCH_TEMPLATE_ID
INFERENTIA_LAUNCH_TEMPLATE_ID=$INFERENTIA_LAUNCH_TEMPLATE_ID
TRAINIUM_LAUNCH_TEMPLATE_ID=$TRAINIUM_LAUNCH_TEMPLATE_ID
RESOURCES

echo "Launch template creation completed successfully."
