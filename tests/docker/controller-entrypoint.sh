#!/bin/bash
set -e

# Start system services
echo "Starting system services..."
mkdir -p /var/log/slurm
chown slurm:slurm /var/log/slurm
/usr/sbin/sshd

# Set up NFS exports
echo "Setting up NFS exports..."
echo "/export/home *(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports
echo "/export/apps *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
echo "/export/scratch *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
echo "/export/slurm *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports

# Start NFS server
echo "Starting NFS server..."
mkdir -p /var/lib/nfs/rpc_pipefs
mkdir -p /var/lib/nfs/v4recovery
exportfs -a
rpcbind
systemctl start nfs-server || echo "NFS server not available in container, starting manually..."
rpc.nfsd
rpc.mountd

# Create munge key
echo "Creating munge key..."
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
cp /etc/munge/munge.key /export/slurm/munge.key

# Start munge
echo "Starting munge..."
runuser -u munge -- /usr/sbin/munged

# Configure Slurm
echo "Configuring Slurm..."
mkdir -p /export/slurm
cp /etc/slurm/slurm.conf /export/slurm/
chown -R slurm:slurm /export/slurm

# Start MariaDB for Slurm accounting
echo "Starting MariaDB for Slurm accounting..."
mysql_install_db --user=mysql --ldata=/var/lib/mysql
/usr/bin/mysqld_safe --datadir=/var/lib/mysql &
sleep 5

# Create Slurm accounting database
echo "Creating Slurm accounting database..."
mysql -e "CREATE DATABASE IF NOT EXISTS slurm_acct_db;"
mysql -e "CREATE USER IF NOT EXISTS 'slurm'@'localhost' IDENTIFIED BY 'password';"
mysql -e "GRANT ALL ON slurm_acct_db.* TO 'slurm'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Start Slurm controller
echo "Starting Slurm controller..."
/usr/sbin/slurmctld

# If test mode is enabled, configure AWS mock environment
if [ -n "$MOCK_AWS_ENDPOINT" ]; then
    echo "Configuring AWS mock environment..."
    echo "export AWS_ENDPOINT_URL=$MOCK_AWS_ENDPOINT" >> /etc/profile.d/aws-mock.sh
    echo "export TEST_MODE=true" >> /etc/profile.d/aws-mock.sh
    
    # Configure AWS CLI for LocalStack
    mkdir -p /root/.aws
    cat > /root/.aws/config << EOF
[default]
region = us-west-2
output = json
endpoint_url = $MOCK_AWS_ENDPOINT
EOF

    cat > /root/.aws/credentials << EOF
[default]
aws_access_key_id = test
aws_secret_access_key = test
EOF

    # Test AWS connectivity
    echo "Testing AWS connectivity to LocalStack..."
    aws --endpoint-url=$MOCK_AWS_ENDPOINT ec2 describe-vpcs || echo "LocalStack not ready yet, will retry later"
fi

echo "Controller setup complete!"

# Keep the container running
exec "$@"