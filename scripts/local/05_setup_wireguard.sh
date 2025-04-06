#!/bin/bash
# WireGuard setup script
set -e

# Install WireGuard
echo "Installing WireGuard..."
sudo dnf install -y wireguard-tools

# Generate keypair
echo "Generating WireGuard keypair..."
sudo mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077
wg genkey | sudo tee privatekey | wg pubkey | sudo tee publickey

# Get the private and public keys
LOCAL_PRIVATE_KEY=$(sudo cat /etc/wireguard/privatekey)
LOCAL_PUBLIC_KEY=$(sudo cat /etc/wireguard/publickey)

# Create initial WireGuard configuration
echo "Creating WireGuard configuration..."
cat << WGCONFIG | sudo tee /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $LOCAL_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820

# AWS Bastion will be added here
WGCONFIG

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure firewall for WireGuard
echo "Configuring firewall..."
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=ldap
sudo firewall-cmd --permanent --add-service=mysql
sudo firewall-cmd --reload

# Add WireGuard monitoring script
echo "Creating WireGuard monitoring script..."
cat << 'WGMONITOR' | sudo tee /usr/local/sbin/wireguard-monitor.sh
#!/bin/bash
# Monitor and maintain WireGuard connection
# Add to crontab: */5 * * * * /usr/local/sbin/wireguard-monitor.sh > /dev/null 2>&1

# Get bastion IP from configuration
BASTION_IP=$(grep "Endpoint" /etc/wireguard/wg0.conf | cut -d':' -f1 | cut -d' ' -f3)
WG_INTERFACE="wg0"
PING_COUNT=3
LOG_FILE="/var/log/wireguard-monitor.log"

# Check if bastion IP is configured
if [ -z "$BASTION_IP" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bastion IP not yet configured in WireGuard config" >> $LOG_FILE
  exit 0
fi

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# Check if interface exists
if ! ip link show $WG_INTERFACE &>/dev/null; then
  log "WireGuard interface $WG_INTERFACE does not exist, starting..."
  systemctl start wg-quick@$WG_INTERFACE
  sleep 5
fi

# Check if interface is up
if ! ip link show $WG_INTERFACE | grep -q "UP"; then
  log "WireGuard interface $WG_INTERFACE is down, bringing up..."
  ip link set $WG_INTERFACE up
  sleep 2
fi

# Check if we can ping the bastion
if ! ping -c $PING_COUNT -W 2 $BASTION_IP &>/dev/null; then
  log "Cannot ping bastion ($BASTION_IP), restarting WireGuard..."
  systemctl restart wg-quick@$WG_INTERFACE
  sleep 5
  
  # Check if restart fixed the issue
  if ping -c $PING_COUNT -W 2 $BASTION_IP &>/dev/null; then
    log "WireGuard connection restored"
  else
    log "WireGuard connection still down after restart"
  fi
else
  # Check if we can ping through to private subnet
  if ! ping -c $PING_COUNT -W 2 10.1.1.1 &>/dev/null; then
    log "Cannot ping private subnet, checking routes..."
    
    # Check if route exists
    if ! ip route | grep -q "10.1.1.0/24"; then
      log "Adding route to private subnet..."
      ip route add 10.1.1.0/24 via $BASTION_IP dev $WG_INTERFACE
    fi
  fi
fi
WGMONITOR

sudo chmod +x /usr/local/sbin/wireguard-monitor.sh

# Add to crontab
echo "Adding WireGuard monitor to crontab..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/sbin/wireguard-monitor.sh") | crontab -

echo "WireGuard setup completed. Note that the tunnel will be fully configured after AWS setup."
