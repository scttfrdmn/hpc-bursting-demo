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
    python3 \
    nfs-utils \
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

# Install Slurm
RUN dnf install -y slurm slurm-slurmd

# Set up SSH
RUN ssh-keygen -A \
    && mkdir -p /run/sshd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "root:password" | chpasswd

# Create Slurm directories
RUN mkdir -p /etc/slurm /var/spool/slurm /var/log/slurm /etc/munge \
    && mkdir -p /home /apps /scratch

# Create Slurm user
RUN groupadd -g 981 slurm \
    && useradd -u 981 -g slurm -s /bin/bash slurm \
    && chown -R slurm:slurm /var/spool/slurm /var/log/slurm

# Create entrypoint script
COPY compute-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]