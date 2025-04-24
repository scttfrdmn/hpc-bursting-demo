#!/bin/bash
set -e

# Start system services
echo "Starting system services..."
mkdir -p /var/log/slurm
chown slurm:slurm /var/log/slurm
/usr/sbin/sshd

# Wait for controller to be ready
echo "Waiting for controller..."
until ping -c 1 $CONTROLLER_IP &>/dev/null; do
    echo "Controller not ready, waiting..."
    sleep 5
done

# Mount NFS shares from controller
echo "Mounting NFS shares..."
mkdir -p /home /apps /scratch /etc/slurm

echo "$CONTROLLER_IP:/export/home /home nfs defaults 0 0" >> /etc/fstab
echo "$CONTROLLER_IP:/export/apps /apps nfs defaults 0 0" >> /etc/fstab
echo "$CONTROLLER_IP:/export/scratch /scratch nfs defaults 0 0" >> /etc/fstab
echo "$CONTROLLER_IP:/export/slurm /etc/slurm nfs defaults 0 0" >> /etc/fstab

mount -a || echo "Failed to mount NFS shares, will retry..."

# Wait for munge key
echo "Waiting for munge key..."
until [ -f /etc/slurm/munge.key ]; do
    echo "Munge key not available, waiting..."
    sleep 5
done

# Set up munge
echo "Setting up munge..."
cp /etc/slurm/munge.key /etc/munge/munge.key
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

# Start munge
echo "Starting munge..."
runuser -u munge -- /usr/sbin/munged

# Start Slurm compute service
echo "Starting Slurm compute service..."
/usr/sbin/slurmd

echo "Compute node setup complete!"

# Keep the container running
exec "$@"