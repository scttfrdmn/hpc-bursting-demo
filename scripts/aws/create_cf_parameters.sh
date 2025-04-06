#!/bin/bash
# Create CloudFormation parameters file from AMI IDs in aws-resources.txt
set -e

# Check for aws-resources.txt
if [ ! -f "../aws-resources.txt" ]; then
  echo "Error: aws-resources.txt not found"
  exit 1
fi

# Source the resource file
source ../aws-resources.txt

# Create directory if it doesn't exist
mkdir -p ../cloudformation

# Determine which AMIs to include based on architecture
if [ "$ARCH" == "arm64" ]; then
  # ARM64 architecture
  cat << PARAMJSON > ../cloudformation/ami-parameters.json
[
  {
    "ParameterKey": "ARM64CPUAMI",
    "ParameterValue": "$CPU_AMI_ID"
  },
  {
    "ParameterKey": "ARM64GPUAMI",
    "ParameterValue": "$GPU_AMI_ID"
  },
  {
    "ParameterKey": "X86CPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "X86GPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "Architecture",
    "ParameterValue": "arm64"
  }
]
PARAMJSON
else
  # X86_64 architecture
  cat << PARAMJSON > ../cloudformation/ami-parameters.json
[
  {
    "ParameterKey": "X86CPUAMI",
    "ParameterValue": "$CPU_AMI_ID"
  },
  {
    "ParameterKey": "X86GPUAMI",
    "ParameterValue": "$GPU_AMI_ID"
  },
  {
    "ParameterKey": "ARM64CPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "ARM64GPUAMI",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "Architecture",
    "ParameterValue": "x86_64"
  }
]
PARAMJSON
fi

echo "CloudFormation parameters file created: ../cloudformation/ami-parameters.json"
