#!/bin/bash
# Autoscript by Mahboub Million (fixed version)

set -e  # Exit on error

# Update system
apt-get update && apt-get upgrade -y
apt install -y net-tools screen iptables iptables-persistent wget openssl

# User inputs
read -p "Record A Domain For Certificate (default: a.domain.com): " -e -i a.domain.com cert
read -p "NS Domain (default: ns.domain.com): " -e -i ns.domain.com DnsNS
read -p "Ports to forward (comma-separated, e.g. 22,443,80): " -e -i 22 PORTS

# Generate certificate
mkdir -p /root/slipstream/certs
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 \
  -nodes -keyout /root/slipstream/certs/key.pem \
  -out /root/slipstream/certs/cert.pem \
  -subj "/CN=$cert"

# Install slipstream binary
  wget -O https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-server-v0.0.2
  chmod +x slipstream-server-v0.0.2
fi

# Stop old screen session if running
screen -S slipstream -X quit || true

# Start new slipstream session
for PORT in $(echo $PORTS | tr ',' ' '); do
  screen -dmS slipstream ~/slipstream-server-v0.0.2 \
    --target-address=127.0.0.1:$PORT \
    --domain=$DnsNS \
    --cert=/root/slipstream/certs/cert.pem \
    --key=/root/slipstream/certs/key.pem \
    --dns-listen-port=5300
done

# Firewall rules
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5300
netfilter-persistent save

echo "✅ Slipstream setup complete. Forwarding ports: $PORTS"
