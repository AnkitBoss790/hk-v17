#!/bin/bash

# Full Incus Admin Init Setup Script with IPv4/IPv6 Support
# Customized for host IPv4: 137.175.89.55 (assumes NAT sharing for containers)
# IPv6: fe80::be24:11ff:fec3:9f8 (link-local; global IPv6 requires provider config)
# Run as root on Ubuntu 22.04+ : chmod +x install.sh && sudo ./install.sh
# Assumes host interface is 'eth0' (change if needed, e.g., enp1s0)
# For public IPs on containers: Use macvlan (see notes at end)

set -e  # Exit on error

HOST_IPV4="137.175.89.55"
HOST_IPV6_LINKLOCAL="fe80::be24:11ff:fec3:9f8"
HOST_IFACE="eth0"  # Change to your host network interface
STORAGE_POOL="btrpool"
BRIDGE_NAME="incusbr0"

echo "=== Full Incus Installation and Setup ==="
echo "Host IPv4: $HOST_IPV4 | IPv6 Link-Local: $HOST_IPV6_LINKLOCAL"
echo "Interface: $HOST_IFACE | Storage: $STORAGE_POOL | Bridge: $BRIDGE_NAME"

# 1. Update system
echo "Updating system..."
apt update && apt upgrade -y

# 2. Install Incus (from official method)
echo "Installing Incus..."
curl -s https://raw.githubusercontent.com/Ankitboss790/hk-v17/install.sh/main/install.sh | bash

# 3. Add current user to incus-admin group
echo "Adding user to incus-admin group..."
usermod -aG incus-admin $SUDO_USER

# 4. Initialize Incus (auto mode: creates default bridge with NAT for IPv4/IPv6)
echo "Initializing Incus..."
incus admin init --auto

# 5. Configure storage pool (BTRFS example; adjust source if needed)
echo "Creating storage pool $STORAGE_POOL..."
# Assume BTRFS: Create if not exists, or use dir/zfs
mkfs.btrfs -f /dev/sdb1  # Example: Change /dev/sdb1 to your disk
incus storage create $STORAGE_POOL btrfs source=/dev/sdb1
# Alternative for dir: incus storage create $STORAGE_POOL dir source=/var/lib/incus/storage

# 6. Customize default bridge for NAT (shares host's public IPv4/IPv6)
echo "Configuring bridge $BRIDGE_NAME with NAT..."
incus network set $BRIDGE_NAME ipv4.nat=true ipv6.nat=true
# Default is private subnet; containers share host's $HOST_IPV4 via NAT for outbound
# For inbound: Use host firewall port forwarding (e.g., iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to 10.0.4.2:80)

# 7. Enable IPv6 if global prefix available (ULA by default; replace with provider prefix if known)
# Example: If global IPv6 prefix is 2001:db8::/64, set:
# incus network set $BRIDGE_NAME ipv6.address=auto  # Or manual: 2001:db8::1/64

# 8. Set default profile to use bridge and storage
echo "Updating default profile..."
incus profile device set default eth0 network=$BRIDGE_NAME
incus profile device set default root pool=$STORAGE_POOL

# 9. Verify setup
echo "Verifying setup..."
incus storage ls
incus network ls
incus profile show default

# 10. Firewall: Allow Incus traffic (nftables auto-managed, but ensure host allows)
echo "Configuring basic firewall..."
ufw allow from 10.0.4.0/24  # Example for bridge subnet
ufw --force enable

echo "=== Incus Setup Complete! ==="
echo "1. Reboot: sudo reboot"
echo "2. newgrp incus-admin (or logout/login)"
echo "3. Test launch: incus launch ubuntu:22.04 test"
echo "4. Container IPs: Private (e.g., 10.0.4.x) with NAT to host $HOST_IPV4"
echo "   - Outbound: Shares host public IP"
echo "   - Inbound: Port forward on host (e.g., iptables -t nat -A PREROUTING -i $HOST_IFACE -p tcp --dport 80 -j DNAT --to 10.0.4.2:80)"
echo "5. IPv6: Link-local $HOST_IPV6_LINKLOCAL; for global, configure provider prefix in bridge"
echo "Download link: https://gist.githubusercontent.com/yourusername/abc123/raw/install-incus-full.sh (Upload this script to GitHub Gist)"

# Optional: Macvlan for Direct Public IPs on Containers (if you have additional IPs/subnet)
echo ""
echo "=== Optional: Macvlan for Public IPs ==="
echo "# If you have a /29 subnet (e.g., including 137.175.89.55), create macvlan profile"
echo "# incus profile create public-macvlan"
echo "# incus profile device add public-macvlan eth0 nic nictype=macvlan parent=$HOST_IFACE"
echo "# Launch: incus launch ubuntu:22.04 public-test --profile default --profile public-macvlan"
echo "# Inside container, set static IP via netplan (e.g., 137.175.89.56/29, gateway from provider)"
echo "# Note: Host-container isolation; get subnet details from provider"
