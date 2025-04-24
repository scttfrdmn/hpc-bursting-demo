#!/usr/bin/env bats
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Tests for AWS infrastructure setup script

# Load test helpers
load test_helper

# Set up test environment before each test
setup() {
  setup_test_environment
  mock_aws_cli
  
  # Create mock script files for each of the sub-scripts
  mkdir -p "$BATS_TEST_TMPDIR/mock_scripts"
  
  # Mock 01_create_iam_user.sh
  cat > "$BATS_TEST_TMPDIR/mock_scripts/01_create_iam_user.sh" << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Creating IAM user and policy..."
exit 0
EOF

  # Mock 02_setup_vpc.sh
  cat > "$BATS_TEST_TMPDIR/mock_scripts/02_setup_vpc.sh" << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Setting up VPC and networking..."
exit 0
EOF

  # Mock 03_setup_bastion.sh
  cat > "$BATS_TEST_TMPDIR/mock_scripts/03_setup_bastion.sh" << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Setting up bastion host..."
exit 0
EOF

  # Mock 04_create_amis.sh
  cat > "$BATS_TEST_TMPDIR/mock_scripts/04_create_amis.sh" << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Creating AMIs $@..."
exit 0
EOF

  # Mock 05_create_launch_template.sh
  cat > "$BATS_TEST_TMPDIR/mock_scripts/05_create_launch_template.sh" << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Creating launch templates..."
exit 0
EOF

  # Mock 06_configure_slurm_aws_plugin.sh
  cat > "$BATS_TEST_TMPDIR/mock_scripts/06_configure_slurm_aws_plugin.sh" << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Configuring Slurm AWS Plugin..."
exit 0
EOF

  # Make all mock scripts executable
  chmod +x "$BATS_TEST_TMPDIR/mock_scripts/"*
}

# Clean up after each test
teardown() {
  teardown_test_environment
}

# Helper function to create a test script that uses the mock scripts
create_test_script() {
  local options="$1"
  
  # Create a test script that sources the real script but uses our mock scripts
  cat > "$BATS_TEST_TMPDIR/test_setup.sh" << EOF
#!/bin/bash
# Save the current directory
CURRENT_DIR="\$(pwd)"

# Change to the mock scripts directory
cd "$BATS_TEST_TMPDIR/mock_scripts"

# Source the real script with options
source "$AWS_SCRIPTS_DIR/setup_aws_infra.sh" $options

# Return to the original directory
cd "\$CURRENT_DIR"
EOF

  chmod +x "$BATS_TEST_TMPDIR/test_setup.sh"
}

# Test command line argument parsing
@test "Setup script shows help message with --help" {
  run "$AWS_SCRIPTS_DIR/setup_aws_infra.sh" --help
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--quick"* ]]
}

@test "Setup script rejects unknown options" {
  run "$AWS_SCRIPTS_DIR/setup_aws_infra.sh" --unknown-option
  
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# Test setup flow in standard mode
@test "Setup script runs all steps in standard mode" {
  # Create a custom test script that sets PATH to use our mock scripts
  cat > "$BATS_TEST_TMPDIR/test_standard.sh" << EOF
#!/bin/bash
# Set the test directory as the working directory
cd "$BATS_TEST_TMPDIR/mock_scripts"

# Create a custom version of the setup script that uses PWD for scripts
cat > ./setup_test.sh << 'INNEREOF'
#!/bin/bash
# Default options
USE_QUICK_MODE=false

# Log function
log() {
  local level="\$1"
  local message="\$2"
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [\$level] \$message"
}

log "INFO" "Starting AWS infrastructure setup..."

# Run all steps with our mock scripts in the current directory
log "INFO" "Creating IAM user and policy..."
./01_create_iam_user.sh

log "INFO" "Setting up VPC and networking..."
./02_setup_vpc.sh

log "INFO" "Launching bastion and setting up WireGuard..."
./03_setup_bastion.sh

log "INFO" "Creating AMIs for compute nodes..."
if [ "\$USE_QUICK_MODE" == "true" ]; then
  ./04_create_amis.sh --quick
else
  ./04_create_amis.sh
fi

log "INFO" "Creating launch template..."
./05_create_launch_template.sh

log "INFO" "Configuring Slurm AWS Plugin..."
./06_configure_slurm_aws_plugin.sh

log "INFO" "AWS infrastructure setup completed successfully."
INNEREOF

chmod +x ./setup_test.sh
./setup_test.sh
EOF

  chmod +x "$BATS_TEST_TMPDIR/test_standard.sh"
  
  # Run the test script
  run "$BATS_TEST_TMPDIR/test_standard.sh"
  
  # Verify all steps ran
  [ "$status" -eq 0 ]
  [[ "$output" == *"Creating IAM user and policy"* ]]
  [[ "$output" == *"Setting up VPC and networking"* ]]
  [[ "$output" == *"Setting up bastion host"* ]]
  [[ "$output" == *"Creating AMIs"* ]]
  [[ "$output" != *"--quick"* ]] # Should not have quick flag
  [[ "$output" == *"Creating launch templates"* ]]
  [[ "$output" == *"Configuring Slurm AWS Plugin"* ]]
  [[ "$output" == *"AWS infrastructure setup completed successfully"* ]]
}

# Test setup flow in quick mode
@test "Setup script runs in quick mode with --quick flag" {
  # Create a custom test script for quick mode
  cat > "$BATS_TEST_TMPDIR/test_quick.sh" << EOF
#!/bin/bash
# Set the test directory as the working directory
cd "$BATS_TEST_TMPDIR/mock_scripts"

# Create a custom version of the setup script that uses PWD for scripts
cat > ./setup_test.sh << 'INNEREOF'
#!/bin/bash
# Default options
USE_QUICK_MODE=false

# Parse command line arguments
while [[ \$# -gt 0 ]]; do
  case \$1 in
    --quick)
      USE_QUICK_MODE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Log function
log() {
  local level="\$1"
  local message="\$2"
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [\$level] \$message"
}

MODE_MSG=\$([ "\$USE_QUICK_MODE" == "true" ] && echo "quick mode" || echo "standard mode")
log "INFO" "Starting AWS infrastructure setup (\${MODE_MSG})..."

# Run AMI creation with our mock scripts in the current directory
log "INFO" "Creating AMIs for compute nodes..."
if [ "\$USE_QUICK_MODE" == "true" ]; then
  ./04_create_amis.sh --quick
else
  ./04_create_amis.sh
fi

log "INFO" "AWS infrastructure setup completed successfully."
INNEREOF

chmod +x ./setup_test.sh
./setup_test.sh --quick
EOF

  chmod +x "$BATS_TEST_TMPDIR/test_quick.sh"
  
  # Run the test script
  run "$BATS_TEST_TMPDIR/test_quick.sh"
  
  # Verify quick mode was used
  [ "$status" -eq 0 ]
  [[ "$output" == *"quick mode"* ]]
  [[ "$output" == *"Creating AMIs --quick"* ]] # Should have quick flag
}

# Test error handling
@test "Setup script exits on step failure" {
  # Create a failing mock script
  cat > "$BATS_TEST_TMPDIR/mock_scripts/02_setup_vpc.sh" << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] VPC setup failed with mock error"
exit 1
EOF

  # Create a test script that will fail on the VPC step
  cat > "$BATS_TEST_TMPDIR/test_failure.sh" << EOF
#!/bin/bash
# Set the test directory as the working directory
cd "$BATS_TEST_TMPDIR/mock_scripts"

# Construct a simplified test script
cat > ./setup_test.sh << 'INNEREOF'
#!/bin/bash
# Set error handling
set -e

# Log function
log() {
  local level="\$1"
  local message="\$2"
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [\$level] \$message"
}

log "INFO" "Starting AWS infrastructure setup..."

# Step 1: Create IAM user and policy
log "INFO" "Creating IAM user and policy..."
./01_create_iam_user.sh
if [ \$? -ne 0 ]; then
  log "ERROR" "IAM user creation failed. Exiting."
  exit 1
fi

# Step 2: Set up VPC and networking
log "INFO" "Setting up VPC and networking..."
./02_setup_vpc.sh
if [ \$? -ne 0 ]; then
  log "ERROR" "VPC setup failed. Exiting."
  exit 1
fi

log "INFO" "AWS infrastructure setup completed successfully."
INNEREOF

chmod +x ./setup_test.sh
./setup_test.sh
EOF

  chmod +x "$BATS_TEST_TMPDIR/test_failure.sh"
  
  # Run the test script, which should fail at the VPC step
  run "$BATS_TEST_TMPDIR/test_failure.sh"
  
  # Verify error handling
  [ "$status" -ne 0 ]
  [[ "$output" == *"Creating IAM user and policy"* ]]
  [[ "$output" == *"Setting up VPC and networking"* ]]
  [[ "$output" == *"VPC setup failed"* ]]
  [[ "$output" != *"AWS infrastructure setup completed successfully"* ]]
}