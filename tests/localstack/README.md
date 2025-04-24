# LocalStack Testing for HPC Bursting Demo

This directory contains configuration and scripts for using LocalStack to test AWS functionality without creating real AWS resources.

## Contents

- `docker-compose.yml` - Configuration for the LocalStack Docker container
- `init-aws.sh` - Script to initialize mock AWS resources in LocalStack
- `start-localstack.sh` - Script to start the LocalStack environment
- `aws-wrapper.sh` - Helper script for using AWS CLI with LocalStack
- `run-aws-tests.sh` - Example script for running tests against LocalStack

## Getting Started

1. Make sure Docker and Docker Compose are installed
2. Start the LocalStack environment:

   ```bash
   ./start-localstack.sh
   ```

3. Run scripts with test mode:

   ```bash
   ./run-aws-tests.sh
   ```

   Or run individual scripts:

   ```bash
   TEST_MODE=true AWS_ENDPOINT_URL=http://localhost:4566 ../../scripts/aws/04_create_amis.sh --test-mode
   ```

## Adding Test Mode to Scripts

Our AWS scripts have been modified to support a `--test-mode` flag that uses the LocalStack environment instead of real AWS resources. To add test mode to a script:

1. Add test mode flag detection in the command line parsing
2. Add AWS endpoint URL configuration for LocalStack
3. Use the `aws_cmd` function for AWS CLI commands
4. Add mock resource generation for test mode
5. Add BATS tests for test mode functionality

## Running Tests

Run the BATS tests to verify test mode functionality:

```bash
cd ..
bats bats/create_amis.bats
```

## Documentation

For more detailed information, see [/docs/localstack-testing.md](/docs/localstack-testing.md).