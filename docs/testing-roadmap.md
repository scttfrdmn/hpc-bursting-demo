# HPC Bursting Demo Testing Roadmap

This document outlines the testing strategy and implementation plan for the HPC Bursting Demo project. The goal is to ensure reliability, stability, and functionality of all components through automated testing.

## Testing Strategy Overview

The testing approach follows a progressive implementation with multiple layers:

1. **Script-Level Testing**: Validate individual scripts function correctly
2. **Mock AWS Testing**: Test AWS interactions without creating real resources
3. **Containerized End-to-End Testing**: Test complete deployment in isolated containers
4. **CI/CD Pipeline Integration**: Automate testing in the development workflow
5. **Infrastructure Testing**: Validate AWS resource creation and configuration
6. **Canary Testing**: Regular scheduled tests to verify functionality
7. **Security Testing**: Validate secure configurations and best practices

## Implementation Phases

### Phase 1: Script-Level Testing (Completed)

- **Required Tools Installation**
  - [x] BATS (Bash Automated Testing System) - For running shell script unit tests
  - [x] ShellCheck - For static analysis and script linting
  - [x] Add installation instructions to documentation (completed in [tests/README.md](../tests/README.md))

- **Shell Script Unit Tests**
  - [x] Set up BATS (Bash Automated Testing System) framework
  - [x] Create unit tests for AWS resource cleanup script
  - [x] Create unit tests for cost monitoring script
  - [x] Create unit tests for AWS infrastructure setup script
  - [x] Create unit tests for AMI creation script
  - [x] Test argument parsing and option handling
  - [x] Test error handling and edge cases
  - [x] Validate output formats and exit codes

- **Static Analysis**
  - [x] Integrate ShellCheck for script validation
  - [x] Document common issues and fixes in [linting-improvements.md](linting-improvements.md)
  - [x] Define and enforce style guidelines
  - [ ] Fix identified linting issues in all scripts *(ongoing effort)*
  - [x] Add pre-commit hooks for automated checking

### Phase 2: Mock AWS Testing (Completed)

- **LocalStack Integration**
  - [x] Set up LocalStack environment with Docker Compose
  - [x] Create initialization script for mock AWS resources
  - [x] Create startup script to manage LocalStack environment
  - [x] Create AWS wrapper script for LocalStack integration
  - [x] Modify AWS scripts to support mock/test mode
  - [x] Complete implementation for all AWS scripts
  - [x] Test resource creation/deletion flow

- **AWS CLI Mocking**
  - [x] Create AWS CLI mock layer for testing
  - [x] Add test mode to simulate AWS responses
  - [x] Create BATS tests for test mode functionality
  - [x] Add comprehensive tests for AWS service interactions

### Phase 3: Containerized Testing (Current Focus)

- **Docker-based Testing Environment**
  - [x] Create Docker containers for local HPC and mock AWS
  - [x] Set up Docker Compose configuration
  - [x] Define network simulation between containers
  - [x] Create automated test scenarios
  - [ ] Test full deployment in containerized environment

### Phase 4: CI/CD Pipeline Integration

- **GitHub Actions Workflow**
  - [ ] Create workflow for running unit tests
  - [ ] Add static analysis checking
  - [ ] Implement container-based integration tests
  - [ ] Create scheduled full integration tests
  - [ ] Add test coverage reporting

### Phase 5: Infrastructure Testing

- **Terraform/Terratest Integration**
  - [ ] Create Terraform equivalent of CloudFormation templates
  - [ ] Implement Terratest test cases
  - [ ] Test infrastructure creation and validation
  - [ ] Add infrastructure compliance tests

### Phase 6: Canary Testing

- **Scheduled Minimal Tests**
  - [ ] Create minimal test infrastructure
  - [ ] Implement scheduled test job execution
  - [ ] Set up monitoring and alerting
  - [ ] Create cleanup safeguards

### Phase 7: Security Testing

- **Security Validation**
  - [ ] Scan for hardcoded credentials
  - [ ] Validate IAM policy least privilege
  - [ ] Check network security configurations
  - [ ] Test permission boundaries

## Current Progress

We have completed Phase 1 (Script-Level Testing) and Phase 2 (Mock AWS Testing), and are making excellent progress on Phase 3 (Containerized Testing). 

For Phase 3, we've created a Docker-based testing environment with three containers:
1. A controller node running the Slurm controller and NFS services
2. A compute node connected to the controller
3. A LocalStack container for AWS service emulation

These containers are configured to create a complete simulation of the HPC bursting environment, with a dedicated network and shared storage volumes. We've created automated test scripts that verify the functionality of the Slurm configuration, NFS mounts, and AWS interactions. The only remaining task is to test the full deployment in this containerized environment.

This comprehensive testing approach allows us to validate the entire HPC bursting workflow without requiring actual hardware or AWS resources, making it ideal for continuous integration and development.

## Testing Guidelines

- Tests should be independent and self-contained
- Tests should clean up after themselves
- Tests should be deterministic and repeatable
- Mock external dependencies when possible
- Document test coverage and gaps
- Prioritize testing critical components first

## Resources

- [BATS Documentation](https://github.com/bats-core/bats-core)
- [ShellCheck Documentation](https://github.com/koalaman/shellcheck)
- [LocalStack Documentation](https://docs.localstack.cloud/overview/)
- [Terratest Documentation](https://terratest.gruntwork.io/docs/)