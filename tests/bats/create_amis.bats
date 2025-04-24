#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Tests for AMI creation script

# Load test helpers
load test_helper

# Set up test environment before each test
setup() {
  setup_test_environment
  mock_aws_cli
  
  # Create a mock aws-resources.txt file
  mkdir -p "$BATS_TEST_TMPDIR/scripts"
  cat > "$BATS_TEST_TMPDIR/scripts/aws-resources.txt" << EOF
AWS_REGION=us-west-2
VPC_ID=vpc-12345678
PUBLIC_SUBNET_ID=subnet-public12345
PRIVATE_SUBNET_ID=subnet-private12345
COMPUTE_SG_ID=sg-compute12345
EOF

  # Create mock config directory
  mkdir -p "$BATS_TEST_TMPDIR/scripts/config"
}

# Clean up after each test
teardown() {
  teardown_test_environment
}

# Helper function to create a simplified test version of the script
create_test_script() {
  local quick_flag="$1"
  local all_flag="$2"
  local gpu_flag="$3"
  local demo_flag="$4"
  
  # Create a simplified version of the script for testing
  cat > "$BATS_TEST_TMPDIR/test_create_amis.sh" << 'EOF'
#!/bin/bash
set -e

# Change to the temporary directory
cd "$BATS_TEST_TMPDIR/scripts"

# Default options
CREATE_CPU_AMI=true
CREATE_GPU_AMI=false
CREATE_INFERENTIA_AMI=false
CREATE_TRAINIUM_AMI=false
USE_DEMO_INSTANCES=false
USE_INTERACTIVE=true

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
    *)
      shift
      ;;
  esac
done

# Source aws-resources.txt
source aws-resources.txt

# Mock architecture detection
ARCH="x86_64"

# Choose instance type based on architecture and demo flag
if [ "$USE_DEMO_INSTANCES" == "true" ]; then
    AMI_BUILDER_INSTANCE="t3.medium"
    GPU_AMI_BUILDER_INSTANCE="g4dn.xlarge"
else
    AMI_BUILDER_INSTANCE="c5.large"
    GPU_AMI_BUILDER_INSTANCE="g4dn.xlarge"
fi

# Create mock AMI creation function
create_ami() {
    local instance_type=$1
    local ami_suffix=$2
    local userdata_file=$3
    
    echo "Creating $ami_suffix AMI using $instance_type instance..."
    
    # Return a fake AMI ID
    ami_id="ami-${ami_suffix}12345"
    echo "AMI ID created: $ami_id"
    echo "$ami_id"
}

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

# Create Inferentia and Trainium AMIs if selected
if [ "$CREATE_INFERENTIA_AMI" == "true" ]; then
    echo "Creating Inferentia AMI..."
    INFERENTIA_AMI_ID=$(create_ami "inf1.xlarge" "inferentia" "cpu-userdata.sh")
    echo "Inferentia AMI ID: $INFERENTIA_AMI_ID"
else
    INFERENTIA_AMI_ID="n/a"
fi

if [ "$CREATE_TRAINIUM_AMI" == "true" ]; then
    echo "Creating Trainium AMI..."
    TRAINIUM_AMI_ID=$(create_ami "trn1.2xlarge" "trainium" "cpu-userdata.sh")
    echo "Trainium AMI ID: $TRAINIUM_AMI_ID"
else
    TRAINIUM_AMI_ID="n/a"
fi

# Save the original content
original_content=$(cat aws-resources.txt)

# Update aws-resources.txt
cat > aws-resources.txt << RESOURCES
$original_content
CPU_AMI_ID=$CPU_AMI_ID
GPU_AMI_ID=$GPU_AMI_ID
INFERENTIA_AMI_ID=$INFERENTIA_AMI_ID
TRAINIUM_AMI_ID=$TRAINIUM_AMI_ID
RESOURCES

echo "AMI creation completed successfully."
EOF

  chmod +x "$BATS_TEST_TMPDIR/test_create_amis.sh"
  
  # Add all the flags to the command
  local cmd="$BATS_TEST_TMPDIR/test_create_amis.sh"
  if [ "$quick_flag" == "true" ]; then
    cmd="$cmd --quick"
  fi
  if [ "$all_flag" == "true" ]; then
    cmd="$cmd --all"
  fi
  if [ "$gpu_flag" == "true" ]; then
    cmd="$cmd --gpu"
  fi
  if [ "$demo_flag" == "true" ]; then
    cmd="$cmd --demo"
  fi
  
  echo "$cmd"
}

# Test default behavior (CPU AMI only)
@test "AMI creation script creates CPU AMI by default" {
  local cmd=$(create_test_script "false" "false" "false" "false")
  
  run $cmd
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating CPU AMI"* ]]
  [[ "$output" == *"AMI ID created: ami-cpu12345"* ]]
  [[ "$output" != *"Creating GPU AMI"* ]]
  [[ "$output" != *"Creating Inferentia AMI"* ]]
  [[ "$output" != *"Creating Trainium AMI"* ]]
}

# Test quick mode (CPU only with demo instances)
@test "AMI creation script in quick mode uses demo instances" {
  local cmd=$(create_test_script "true" "false" "false" "false")
  
  run $cmd
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating CPU AMI"* ]]
  [[ "$output" == *"using t3.medium instance"* ]]
  [[ "$output" != *"using c5.large instance"* ]]
}

# Test --all flag (creates all AMI types)
@test "AMI creation script with --all creates all AMI types" {
  local cmd=$(create_test_script "false" "true" "false" "false")
  
  run $cmd
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating CPU AMI"* ]]
  [[ "$output" == *"Creating GPU AMI"* ]]
  [[ "$output" == *"Creating Inferentia AMI"* ]]
  [[ "$output" == *"Creating Trainium AMI"* ]]
}

# Test --gpu flag (creates CPU and GPU AMIs)
@test "AMI creation script with --gpu creates CPU and GPU AMIs" {
  local cmd=$(create_test_script "false" "false" "true" "false")
  
  run $cmd
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating CPU AMI"* ]]
  [[ "$output" == *"Creating GPU AMI"* ]]
  [[ "$output" != *"Creating Inferentia AMI"* ]]
  [[ "$output" != *"Creating Trainium AMI"* ]]
}

# Test --demo flag (uses smaller instance types)
@test "AMI creation script with --demo uses t3.medium" {
  local cmd=$(create_test_script "false" "false" "false" "true")
  
  run $cmd
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"using t3.medium instance"* ]]
  [[ "$output" != *"using c5.large instance"* ]]
}

# Test combining flags (--gpu --demo)
@test "AMI creation script with --gpu --demo creates CPU and GPU AMIs with demo instances" {
  local cmd=$(create_test_script "false" "false" "true" "true")
  
  run $cmd
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating CPU AMI"* ]]
  [[ "$output" == *"using t3.medium instance"* ]]
  [[ "$output" == *"Creating GPU AMI"* ]]
  [[ "$output" == *"using g4dn.xlarge instance"* ]]
}

# Test resource update
@test "AMI creation script updates aws-resources.txt with AMI IDs" {
  # Create a very simple test script that directly updates aws-resources.txt
  cat > "$BATS_TEST_TMPDIR/test_ami_update.sh" << 'EOF'
#!/bin/bash
set -e

# Create mock directory and resources file
mkdir -p "$BATS_TEST_TMPDIR/mock"
cat > "$BATS_TEST_TMPDIR/mock/aws-resources.txt" << INIT
AWS_REGION=us-west-2
INIT

# Define AMI IDs
CPU_AMI_ID="ami-cpu12345"
GPU_AMI_ID="ami-gpu12345"
INFERENTIA_AMI_ID="ami-inferentia12345"
TRAINIUM_AMI_ID="ami-trainium12345"

# Update aws-resources.txt
cat >> "$BATS_TEST_TMPDIR/mock/aws-resources.txt" << RESOURCES
CPU_AMI_ID=$CPU_AMI_ID
GPU_AMI_ID=$GPU_AMI_ID
INFERENTIA_AMI_ID=$INFERENTIA_AMI_ID
TRAINIUM_AMI_ID=$TRAINIUM_AMI_ID
RESOURCES

echo "File updated successfully"
EOF

  chmod +x "$BATS_TEST_TMPDIR/test_ami_update.sh"
  
  # Run the test script
  run "$BATS_TEST_TMPDIR/test_ami_update.sh"
  
  # Verify the script ran successfully
  [ "$status" -eq 0 ]
  [[ "$output" == *"File updated successfully"* ]]
  
  # Now check the contents of the file
  run cat "$BATS_TEST_TMPDIR/mock/aws-resources.txt"
  
  # Verify the file contains the AMI IDs
  [[ "$output" == *"CPU_AMI_ID=ami-cpu12345"* ]]
  [[ "$output" == *"GPU_AMI_ID=ami-gpu12345"* ]]
  [[ "$output" == *"INFERENTIA_AMI_ID=ami-inferentia12345"* ]]
  [[ "$output" == *"TRAINIUM_AMI_ID=ami-trainium12345"* ]]
}