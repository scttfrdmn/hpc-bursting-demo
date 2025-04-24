FROM rockylinux:9

# Install system dependencies
RUN dnf update -y && dnf install -y \
    epel-release \
    dnf-plugins-core \
    && dnf config-manager --set-enabled crb \
    && dnf update -y \
    && dnf install -y \
    vim \
    wget \
    git \
    curl \
    openssh-server \
    sudo \
    which \
    munge \
    mariadb-server \
    python3 \
    python3-pip \
    jq \
    nfs-utils \
    openldap-servers \
    openldap-clients \
    python3-devel \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    make \
    patch \
    file \
    bzip2 \
    xz \
    unzip \
    zlib-devel \
    && dnf clean all

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Install Slurm
RUN dnf install -y slurm slurm-slurmctld slurm-slurmd

# Set up SSH
RUN ssh-keygen -A \
    && mkdir -p /run/sshd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "root:password" | chpasswd

# Create Slurm directories
RUN mkdir -p /etc/slurm /var/spool/slurm /var/log/slurm /etc/munge \
    && mkdir -p /var/lib/mysql

# Create Slurm user
RUN groupadd -g 981 slurm \
    && useradd -u 981 -g slurm -s /bin/bash slurm \
    && chown -R slurm:slurm /var/spool/slurm /var/log/slurm

# Create shared directories
RUN mkdir -p /export/home /export/apps /export/scratch /export/slurm \
    && mkdir -p /home /apps /scratch

# Create entrypoint script
COPY controller-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create slurm.conf
COPY slurm.conf /etc/slurm/slurm.conf
RUN chown slurm:slurm /etc/slurm/slurm.conf

# Set up AWS credentials for testing
RUN mkdir -p /root/.aws
COPY aws-config /root/.aws/config
COPY aws-credentials /root/.aws/credentials

# Install Python dependencies for AWS
RUN pip3 install boto3 botocore

# Expose ports
EXPOSE 22 6817 6818 6819

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]