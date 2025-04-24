# HPC Bursting Demo Tests

This directory contains automated tests for the HPC Bursting Demo project.

## Overview

The testing framework is built using:
- [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System) for shell script testing
- Mock functions to simulate AWS CLI interactions
- Helper utilities for test setup and teardown

## Prerequisites

To run the tests, you need to have BATS installed. You can install it using one of the following methods:

### MacOS
```bash
brew install bats-core
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install bats
```

### From Source
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

## Running Tests

### Run All Tests
To run all tests:
```bash
./run_tests.sh
```

### Run Specific Test
To run a specific test:
```bash
./run_tests.sh --test cleanup_aws_resources
```

## Test Structure

- `bats/` - Contains all BATS test files
- `test_helper.bash` - Common utilities and setup functions for tests
- `run_tests.sh` - Main script to run all tests

## Writing New Tests

### Naming Convention
- Test files should be named after the script they test, with `.bats` extension
- Example: `cleanup_aws_resources.bats` tests `scripts/aws/cleanup_aws_resources.sh`

### Test Structure
Each test file follows this pattern:
1. Load test helpers: `load test_helper`
2. Define setup and teardown functions
3. Create individual test cases with `@test` annotation
4. Use assertions to validate expected behavior

### Example Test
```bash
#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_environment
}

teardown() {
  teardown_test_environment
}

@test "Script shows help message" {
  run bash /path/to/script.sh --help
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
```

## Mocking AWS CLI

The `test_helper.bash` file provides a `mock_aws_cli` function that:
1. Creates mock response data for common AWS CLI commands
2. Allows tests to run without accessing actual AWS services
3. Provides predictable outputs for verification

To customize AWS mock responses, extend the `aws()` function in your test.

## Continuous Integration

Tests are automatically run on:
- Pull requests to main branch
- Scheduled daily builds
- Manual trigger via GitHub Actions

## See Also

- [Testing Roadmap](/docs/testing-roadmap.md) for the testing strategy and implementation plan