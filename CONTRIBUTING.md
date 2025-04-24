# Contributing to the HPC Bursting Demo

Thank you for your interest in contributing to the HPC Bursting Demo project! This document provides guidelines and instructions for contributing to this project.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Environment](#development-environment)
- [Testing](#testing)
- [Coding Standards](#coding-standards)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How to Contribute

There are many ways to contribute to the HPC Bursting Demo:

1. **Reporting bugs**: If you find a bug, please report it using the GitHub issue tracker.
2. **Suggesting enhancements**: New ideas are always welcome - submit them as issues.
3. **Improving documentation**: Help us make our documentation better and more accessible.
4. **Contributing code**: Submit pull requests with bug fixes or new features.

## Development Environment

To set up your development environment:

1. Fork the repository and clone it to your local machine
2. Install required dependencies:
   - AWS CLI (required for deployment)
   - Bash 4.0 or higher (required for all scripts)
   - Testing tools (required for development and contribution):
     - [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System)
     - [ShellCheck](https://github.com/koalaman/shellcheck) (for shell script linting)

For detailed instructions on installing the testing tools, refer to the [tests/README.md](tests/README.md) file in the repository.

## Testing

The project uses a comprehensive testing strategy outlined in the [Testing Roadmap](docs/testing-roadmap.md).

### Setting Up Pre-commit Hooks

We use Git pre-commit hooks to automatically run linting and tests on changed files. To set up the hooks:

```bash
./scripts/install-git-hooks.sh
```

This will:
- Configure Git to use the hooks in the `.githooks` directory
- Ensure all hooks are executable
- Run ShellCheck and relevant BATS tests when you make a commit

### Running Tests

We use BATS (Bash Automated Testing System) for shell script testing. To run tests:

```bash
cd tests
./run_tests.sh
```

To run a specific test:

```bash
./run_tests.sh --test cleanup_aws_resources
```

### Writing Tests

Please see the [Shell Testing Guide](docs/shell-testing-guide.md) for detailed information about writing effective tests.

### Linting

All shell scripts should be checked with ShellCheck. To run linting manually:

```bash
cd tests
./lint_scripts.sh
```

To lint only a specific directory:

```bash
./lint_scripts.sh --dir scripts/aws
```

For more verbose output:

```bash
./lint_scripts.sh --verbose
```

See [linting-improvements.md](docs/linting-improvements.md) for common linting issues and how to fix them.

## Coding Standards

Please follow these guidelines when writing code:

1. **Shell scripts**:
   - Use Bash for all shell scripts
   - Include SPDX license identifier at the top of every file
   - Follow [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
   - Add error handling for all scripts
   - Include helpful messages and logging

2. **Documentation**:
   - Use Markdown for all documentation
   - Keep language clear and concise
   - Include examples where appropriate
   - Update documentation when changing functionality

3. **Commit messages**:
   - Use clear, descriptive commit messages
   - Start with a verb in imperative form (e.g., "Add", "Fix", "Update")
   - Include references to issues if applicable

## Pull Request Process

1. **Fork the repository**: Create your own fork of the project
2. **Create a branch**: Make your changes in a new branch
3. **Add tests**: Include tests for new functionality
4. **Run tests**: Ensure all tests pass
5. **Update documentation**: Update relevant documentation
6. **Submit a pull request**: Include a clear description of the changes
7. **Code review**: Address any feedback from reviewers

## Release Process

The project maintainers will handle the release process, which includes:

1. Updating version numbers
2. Creating a changelog
3. Tagging releases
4. Publishing releases on GitHub

Thank you for contributing to the HPC Bursting Demo project!