#!/usr/bin/env bash
set -euo pipefail

# Docker-published ports bypass UFW. Keep the robotics-lab HTTP entrypoints private
# even when a future compose file publishes 80/443 on all host addresses.
IPTABLES="${IPTABLES:-/usr/sbin/iptables}"
HOME_CIDR="${HOME_CIDR:-192.168.10.0/24}"
EXTERNAL_INTERFACE="${EXTERNAL_INTERFACE:-eth0}"

"$IPTABLES" -N NEXUS-ROBOTICS-LAB 2>/dev/null || true
"$IPTABLES" -F NEXUS-ROBOTICS-LAB
"$IPTABLES" -A NEXUS-ROBOTICS-LAB -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Apply the ingress restriction only on the VM's LAN interface. Connections
# originating from a Docker bridge must retain outbound access for ACME, DNS,
# package repositories, and other explicitly requested services.
"$IPTABLES" -A NEXUS-ROBOTICS-LAB -i "$EXTERNAL_INTERFACE" -s "$HOME_CIDR" -p tcp -m multiport --dports 80,443,2222 -j ACCEPT
"$IPTABLES" -A NEXUS-ROBOTICS-LAB -i "$EXTERNAL_INTERFACE" -p tcp -m multiport --dports 80,443,2222 -j DROP
"$IPTABLES" -A NEXUS-ROBOTICS-LAB -j RETURN

"$IPTABLES" -C DOCKER-USER -j NEXUS-ROBOTICS-LAB 2>/dev/null || \
  "$IPTABLES" -I DOCKER-USER 1 -j NEXUS-ROBOTICS-LAB
