# Troubleshooting Guide

This guide helps you diagnose and solve common issues with the HPC Bursting Demo.

## Connectivity Issues

### WireGuard Connection Problems

**Symptoms**:
- Cloud nodes can't connect to on-premises resources
- Unable to ping between on-premises and AWS
- `sinfo` shows nodes in DOWN state

**Check WireGuard Status**:
```bash
sudo wg show
```

**Resolution**:
1. Restart WireGuard:
   ```bash
   sudo systemctl restart wg-quick@wg0
   ```

2. Verify configuration matches on both ends:
   ```bash
   # On-premises:
   sudo cat /etc/wireguard/wg0.conf
   
   # On bastion (via SSH):
   ssh -i hpc-demo-key.pem rocky@BASTION_IP sudo cat /etc/wireguard/wg0.conf
   ```

3. Check if the bastion host is reachable:
   ```bash
   ping BASTION_PUBLIC_IP
   ```

4. Verify port 51820 is open in AWS security groups

5. Run the WireGuard monitor to fix connection:
   ```bash
   sudo /usr/local/sbin/wireguard-monitor.sh
   ```

### NFS Mount Issues

**Symptoms**:
- Job failures with "cannot access /home" errors
- Cloud nodes failing to start properly

**Diagnosis**:
```bash
# On cloud node (via SSH):
df -h
mount | grep nfs
```

**Resolution**:
1. Check NFS server status:
   ```bash
   sudo systemctl status nfs-server
   ```

2. Verify NFS exports:
   ```bash
   showmount -e localhost
   ```

3. Check firewall settings:
   ```bash
   sudo firewall-cmd --list-all
   ```

4. Manually mount NFS share for testing:
   ```bash
   sudo mount -t nfs nfs.hpc-demo.internal:/export/home /home
   ```

## Slurm Issues

### Slurm Services Not Running

**Symptoms**:
- Commands like `sinfo` or `squeue` fail
- Jobs do not start

**Diagnosis**:
```bash
sudo systemctl status slurmctld
sudo systemctl status slurmd
sudo systemctl status slurmdbd
```

**Resolution**:
1. Start missing services:
   ```bash
   sudo systemctl start slurmctld
   sudo systemctl start slurmd
   sudo systemctl start slurmdbd
   ```

2. Check logs for issues:
   ```bash
   sudo journalctl -u slurmctld
   sudo tail -50 /var/log/slurm/slurmctld.log
   ```

3. Verify configurations:
   ```bash
   sudo slurmd -C
   ```

### Cloud Nodes Not Starting

**Symptoms**:
- Jobs sit in queue with reason "ReqNodeNotAvail"
- Cloud nodes remain in CLOUD state

**Diagnosis**:
```bash
# Check node status
sinfo -R
scontrol show nodes

# Check AWS plugin log
sudo tail -100 /var/log/slurm/aws_plugin.log
```

**Resolution**:
1. Verify AWS credentials are working:
   ```bash
   aws sts get-caller-identity
   ```

2. Check for AWS API errors in plugin logs:
   ```bash
   grep "error" /var/log/slurm/aws_plugin.log
   ```

3. Verify the subnet and security group IDs in partitions.json:
   ```bash
   sudo cat /etc/slurm/aws/partitions.json
   ```

4. Force node state update:
   ```bash
   sudo /etc/slurm/aws/change_state.py
   ```

5. Manually test launching an instance with AWS CLI:
   ```bash
   aws ec2 run-instances --image-id AMI_ID --instance-type c5.large --subnet-id SUBNET_ID
   ```

## Instance Issues

### Instance Launch Failures

**Symptoms**:
- AWS plugin log shows errors launching instances
- Jobs stay in PENDING state

**Diagnosis**:
```bash
# Get recent AWS plugin logs
sudo tail -100 /var/log/slurm/aws_plugin.log

# Check AWS instance status
aws ec2 describe-instances --filters "Name=tag:Project,Values=HPC-Bursting-Demo"
```

**Resolution**:
1. Verify AWS service quotas:
   ```bash
   aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
   ```

2. Check instance capacity in the region/AZ:
   ```bash
   # Try a different instance type
   vim /etc/slurm/aws/partitions.json
   # Update instance types, regenerate config
   cd /etc/slurm/aws
   sudo ./generate_conf.py
   sudo systemctl restart slurmctld
   ```

3. Check launch template exists and is valid:
   ```bash
   aws ec2 describe-launch-templates --launch-template-names hpc-demo-compute-cpu
   ```

### Instance Can't Access On-premises Resources

**Symptoms**:
- Instance launches but jobs fail
- Cannot access NFS or LDAP

**Resolution**:
1. Verify WireGuard connection (see WireGuard troubleshooting)

2. Check DNS resolution:
   ```bash
   # On cloud instance:
   ping controller.hpc-demo.internal
   ping nfs.hpc-demo.internal
   ```

3. Check route table configuration:
   ```bash
   # On cloud instance:
   ip route show
   
   # On AWS Console:
   Check route table for private subnet has route to 10.0.0.0/24
   ```

## Deployment Issues

### Slow or Failed AMI Creation

**Symptoms**:
- AMI creation process takes too long
- Creation fails due to insufficient memory or CPU

**Diagnosis**:
```bash
# Check AWS CloudTrail for errors
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances
```

**Resolution**:
1. Use quick mode for faster, cheaper deployment:
   ```bash
   ./04_create_amis.sh --quick
   ```

2. Wait longer for instance setup (adjust WAIT_TIME variable in the script)

3. For demo/testing, only create the CPU AMI:
   ```bash
   ./04_create_amis.sh --quick  # CPU-only with t-series instances
   ```

## Cost Management Issues

### Unexpected AWS Charges

**Symptoms**:
- AWS bill higher than expected
- Instances not terminating properly

**Diagnosis**:
```bash
# Check running instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:Project,Values=HPC-Bursting-Demo" --query "Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]" --output table

# Check slurm configuration
grep SuspendTime /etc/slurm/slurm.conf

# Check AWS costs
../scripts/monitor-aws-costs.sh
```

**Resolution**:
1. Terminate unwanted instances:
   ```bash
   aws ec2 terminate-instances --instance-ids i-1234567890abcdef0
   ```

2. Decrease SuspendTime to terminate instances sooner:
   ```bash
   # Edit /etc/slurm/slurm.conf
   # Change SuspendTime=300 to a smaller value
   sudo systemctl restart slurmctld
   ```

3. Set node limits to control maximum spending:
   ```bash
   # Edit /etc/slurm/aws/partitions.json
   # Reduce MaxNodes value
   cd /etc/slurm/aws
   sudo ./generate_conf.py
   sudo systemctl restart slurmctld
   ```

4. If done with the demo, clean up all AWS resources:
   ```bash
   cd scripts/aws
   ./cleanup_aws_resources.sh
   ```

### Resource Cleanup Problems

**Symptoms**:
- Resources remain after attempting cleanup
- Security groups or VPC can't be deleted due to dependencies
- Ongoing charges after demo completion

**Diagnosis**:
```bash
# Check for remaining instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=HPC-Bursting-Demo" --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table

# Check for AMIs
aws ec2 describe-images --owners self --filters "Name=name,Values=hpc-demo*" --query "Images[].ImageId" --output table

# Check for network interfaces
aws ec2 describe-network-interfaces --filters "Name=tag:Project,Values=HPC-Bursting-Demo" --query "NetworkInterfaces[].NetworkInterfaceId" --output table
```

**Resolution**:
1. Use the comprehensive cleanup script with force flag:
   ```bash
   cd scripts/aws
   ./cleanup_aws_resources.sh --force
   ```

2. If CloudFormation was used, delete the stack first:
   ```bash
   aws cloudformation delete-stack --stack-name hpc-bursting-stack
   ```

3. For manual cleanup, follow this order:
   ```bash
   # 1. Terminate instances (including bastion)
   # 2. Deregister AMIs and delete snapshots
   # 3. Delete launch templates
   # 4. Delete network interfaces
   # 5. Delete security groups
   # 6. Delete route tables, subnets, internet gateway, VPC
   # 7. Delete Route53 hosted zone
   # 8. Delete IAM user and policies
   ```

4. Verify resources are gone by checking the monitoring script:
   ```bash
   ../monitor-aws-costs.sh
   ```

### Separation Between Local and AWS Components

The HPC Bursting Demo was designed with a clean separation between the local HPC environment and AWS cloud resources. This has important implications for setup and cleanup:

**Architecture Separation**:
- Local components (NFS, LDAP, Slurm, WireGuard) are configured independently from AWS resources
- AWS resources (EC2, VPC, IAM, etc.) are created separately after local setup
- The interface points are the WireGuard VPN and Slurm AWS plugin configuration

**Benefits for Cleanup and Redeployment**:
- The cleanup script (`cleanup_aws_resources.sh`) only removes AWS resources without affecting local configurations
- After cleanup, the local HPC environment remains fully functional for local jobs
- You can redeploy just the AWS portion later without reconfiguring the local environment

**How to Redeploy Only AWS Resources**:
1. Clean up AWS resources: `./cleanup_aws_resources.sh`
2. When ready to redeploy, run just the AWS setup scripts:
   ```bash
   cd scripts/aws
   ./setup_aws_infra.sh
   ```
3. The AWS setup will automatically reconfigure the necessary connection points:
   - Create new AWS resources with unique IDs
   - Update the WireGuard configuration with new bastion details
   - Reconfigure the Slurm AWS plugin with new resource IDs

This separation makes the system more flexible for testing, demos, and iterative development. You can tear down AWS resources when not in use (saving costs) and quickly redeploy them when needed, all without disrupting your local HPC configuration.

## Authentication Issues

### LDAP Authentication Failures

**Symptoms**:
- Users cannot log in on cloud nodes
- Permission denied errors

**Diagnosis**:
```bash
# Test LDAP lookup
getent passwd testuser

# Check SSSD status
sudo systemctl status sssd
```

**Resolution**:
1. Restart SSSD:
   ```bash
   sudo systemctl restart sssd
   ```

2. Clear SSSD cache:
   ```bash
   sudo rm -rf /var/lib/sss/db/*
   sudo systemctl restart sssd
   ```

3. Check LDAP server connectivity:
   ```bash
   ldapsearch -x -h ldap.hpc-demo.internal -b "dc=demo,dc=local"
   ```

## Collecting Diagnostics

For complex issues, gather complete diagnostic information:

```bash
# Create diagnostics directory
mkdir -p ~/hpc-diagnostics
cd ~/hpc-diagnostics

# Collect Slurm configuration and logs
cp /etc/slurm/slurm.conf .
cp /etc/slurm/aws/partitions.json .
cp /etc/slurm/aws/config.json .
sudo cp /var/log/slurm/slurmctld.log .
sudo cp /var/log/slurm/aws_plugin.log .

# Collect WireGuard configuration
sudo cp /etc/wireguard/wg0.conf wireguard-config.txt

# Get Slurm status
sinfo > sinfo.txt
squeue > squeue.txt
scontrol show nodes > nodes.txt
scontrol show partition > partitions.txt

# Get AWS instance information
aws ec2 describe-instances --filters "Name=tag:Project,Values=HPC-Bursting-Demo" > aws-instances.json

# Create diagnostics tarball
tar -czf hpc-diagnostics.tar.gz *
```

## Getting Further Help

If you're still experiencing issues:

1. Check the GitHub repository for known issues
2. Create a new issue with your diagnostics information
3. Join the project community for direct assistance