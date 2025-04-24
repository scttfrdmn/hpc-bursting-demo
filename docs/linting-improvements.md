# Shell Script Linting Improvements

This document identifies common shell script issues discovered during linting and describes how to fix them.

## Common Issues

The primary issues found by ShellCheck include:

1. **Unquoted Variables**: Variables that may contain spaces or special characters should be quoted.
2. **External Source Files**: Source files not being followed by ShellCheck.
3. **Globbing and Word Splitting**: Potential for unintended behavior due to unquoted variables.

## How to Fix

### 1. Unquoted Variables

**Problem:**
```bash
aws ec2 describe-instances --region $AWS_REGION
```

**Solution:**
```bash
aws ec2 describe-instances --region "$AWS_REGION"
```

Fix all instances of unquoted variables, particularly when used with:
- AWS CLI commands
- Paths
- Command-line arguments
- Variables that might contain spaces

### 2. External Source Files

**Problem:**
```bash
source ../aws-resources.txt
```

ShellCheck can't follow external sources and flags them as errors.

**Solution:**
```bash
# shellcheck source=../aws-resources.txt
source ../aws-resources.txt
```

Add the directive to tell ShellCheck which file to look for.

### 3. File Path Handling

**Problem:**
```bash
cd $BASE_DIR
```

**Solution:**
```bash
cd "$BASE_DIR"
```

Always quote variables that contain file paths.

## Files Needing Fixes

Based on the ShellCheck report, the following files need fixes:

1. `/scripts/aws/01_create_iam_user.sh`
2. `/scripts/aws/02_setup_vpc.sh`
3. `/scripts/aws/03_setup_bastion.sh`
4. `/scripts/aws/04_create_amis.sh`
5. `/scripts/aws/05_create_launch_template.sh`
6. `/scripts/aws/06_configure_slurm_aws_plugin.sh`
7. `/scripts/aws/create_cf_parameters.sh`
8. `/scripts/aws/setup_aws_infra.sh`
9. `/scripts/local/*` (all files)

## Implementation Strategy

1. Add the following shellcheck directive to all script files that source external files:
   ```bash
   # shellcheck source=../path/to/sourced/file.sh
   source ../path/to/sourced/file.sh
   ```

2. Fix variable quoting issues by adding double quotes around all variable references in command arguments:
   ```bash
   aws ec2 describe-instances --region "$AWS_REGION"
   ```

3. Ensure proper quoting in loops and conditionals:
   ```bash
   for ID in $IDS; do   # Bad
   for ID in "$IDS"; do # Good (if $IDS is a space-separated list)
   
   # Or better:
   IFS=' ' read -ra ID_ARRAY <<< "$IDS"
   for ID in "${ID_ARRAY[@]}"; do
   ```

4. Add ShellCheck to the CI/CD pipeline to prevent these issues in the future.

## Example of Fixed Code

**Before:**
```bash
# Load resource IDs from file
if [ -f "../aws-resources.txt" ]; then
  source ../aws-resources.txt
  
  aws ec2 terminate-instances \
    --instance-ids $INSTANCE_IDS \
    --region $AWS_REGION
fi
```

**After:**
```bash
# Load resource IDs from file
if [ -f "../aws-resources.txt" ]; then
  # shellcheck source=../aws-resources.txt
  source ../aws-resources.txt
  
  aws ec2 terminate-instances \
    --instance-ids "$INSTANCE_IDS" \
    --region "$AWS_REGION"
fi
```

## Progress Tracking

- [x] Identify issues with ShellCheck
- [x] Document common issues and fixes
- [x] Fix example script (cleanup_aws_resources.sh)
- [ ] Fix remaining AWS scripts
- [ ] Fix local scripts
- [ ] Add ShellCheck to CI/CD pipeline

## References

- [ShellCheck Documentation](https://github.com/koalaman/shellcheck)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Pitfalls](http://mywiki.wooledge.org/BashPitfalls)