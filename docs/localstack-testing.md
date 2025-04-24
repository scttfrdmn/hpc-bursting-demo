# LocalStack Testing Guide

This guide explains how to use LocalStack for mock AWS testing in the HPC Bursting Demo project.

## Overview

LocalStack is a cloud service emulator that runs in a Docker container and provides a testing environment for AWS cloud applications. It allows us to test our AWS scripts and infrastructure code without creating real AWS resources, saving time and money.

## Setup

The LocalStack environment has been configured with the following components:

1. `docker-compose.yml` - Defines the LocalStack container configuration
2. `init-aws.sh` - Creates mock AWS resources during LocalStack startup
3. `start-localstack.sh` - Script to manage the LocalStack environment
4. `aws-wrapper.sh` - Helper script for using LocalStack with AWS CLI
5. `run-aws-tests.sh` - Example script showing how to run tests with LocalStack

## Getting Started

### Prerequisites

- Docker and Docker Compose installed on your machine
- AWS CLI installed on your machine

### Starting the LocalStack Environment

To start the LocalStack environment, run:

```bash
cd tests/localstack
./start-localstack.sh
```

This script will:
- Start the LocalStack Docker container
- Initialize mock AWS resources via `init-aws.sh`
- Set environment variables for testing

### Running Scripts in Test Mode

To run an AWS script in test mode, use the `--test-mode` flag:

```bash
# Run with test mode to use LocalStack
TEST_MODE=true AWS_ENDPOINT_URL=http://localhost:4566 scripts/aws/04_create_amis.sh --test-mode
```

Alternatively, you can source the environment from start-localstack.sh:

```bash
source <(tests/localstack/start-localstack.sh --env-only)
scripts/aws/04_create_amis.sh --test-mode
```

### Available Mock Resources

The following AWS resources are mocked in LocalStack:

- VPC with public and private subnets
- Security groups
- IAM roles and policies
- S3 buckets
- CloudFormation stacks
- EC2 instances and AMIs

## Test Mode in Scripts

AWS scripts have been modified to support a `--test-mode` flag that:

1. Uses the LocalStack endpoint for AWS CLI commands
2. Skips long-running operations like instance creation
3. Uses mock resource IDs for testing
4. Maintains the same logical flow as normal operation

### Implementing Test Mode in Scripts

Scripts use an `aws_cmd` function that dynamically routes AWS CLI commands:

```bash
aws_cmd() {
    if [ "$TEST_MODE" = "true" ]; then
        aws --endpoint-url="$AWS_ENDPOINT_URL" "$@"
    else
        aws "$@"
    fi
}
```

### Example Test Mode Implementation

The AMI creation script (04_create_amis.sh) has been modified to support test mode:

1. Added `--test-mode` command line option
2. Added test mode detection and endpoint configuration
3. Added `aws_cmd` function for AWS CLI routing
4. Added mock resource generation for test mode
5. Added BATS tests for test mode functionality

## Running Tests

To run the BATS tests for the LocalStack-integrated scripts:

```bash
cd tests
bats bats/create_amis.bats
```

## Extending Test Coverage

To add test mode support to additional scripts:

1. Add test mode detection to the script
2. Add the `aws_cmd` function for AWS CLI command routing 
3. Add conditional logic for test mode operations
4. Add BATS tests for the test mode functionality

## Limitations

- Some AWS services may not be fully emulated by LocalStack
- Complex workflows may require adjustments to work with LocalStack
- Performance may differ from real AWS services

## References

- [LocalStack Documentation](https://docs.localstack.cloud/overview/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/reference/)