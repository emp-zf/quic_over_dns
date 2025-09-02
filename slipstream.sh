#!/bin/bash
# Autoscript by Mahboub Million (fixed & hardened)

set -euo pipefail

# Require root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

# Update system & install deps
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install -y net-tools screen iptables-persistent wget openssl

# User inputs
read -p "Record A Domain For Certificate (default: a.domain.com): " -e -i a.domain.com cert
read -p "NS Domain (default: ns.domain.com): " -e -i ns.domain.com DnsNS
read -p "Ports to forward (comma-separated, e.g. 22,443,80): " -e -i 22 PORTS

# Paths
CERT_DIR="/root/slipstream/certs"
KEY_PATH="$CERT_DIR/key.pem"
CERT_PATH="$CERT_DIR/cert.pem"
BIN="/usr/local/bin/slipstream-server-v0.0.2"
DNS_PORT=5300

# Generate certificate (self-signed)
mkdir -p "$CERT_DIR"
if [[ ! -f "$KEY_PATH" || ! -f "$CERT_PATH" ]]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 365 \
    -nodes -keyout "$KEY_PATH" \
    -out "$CERT_PATH" \
    -subj "/CN=$cert"
fi

# Install slipstream binary if missing
if [[ ! -x "$BIN" ]]; then
  echo "Downloading slipstream server binary..."
  wget -O "$BIN" "https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-server-v0.0.2"
  chmod +x "$BIN"
fi

# Build target address args from comma-separated ports
IFS=',' read -r -a PORT_ARR <<< "$PORTS"
TARGET_ARGS=()
for p in "${PORT_ARR[@]}"; do
  p_trim="$(echo "$p" | xargs)"
  [[ -z "$p_trim" ]] && continue
  if [[ "$p_trim" =~ ^[0-9]+$ ]] && (( p_trim > 0 && p_trim < 65536 )); then
    TARGET_ARGS+=( "--target-address=127.0.0.1:${p_trim}" )
  else
    echo "Skipping invalid port: $p_trim" >&2
  fi
done

if [[ ${#TARGET_ARGS[@]} -eq 0 ]]; then
  echo "No valid ports provided. Exiting." >&2
  exit 1
fi

# Stop old screen session if running
screen -S slipstream -X quit || true

# Start a single slipstream instance (supports multiple --target-address flags)
screen -dmS slipstream "$BIN" \
  "${TARGET_ARGS[@]}" \
  --domain="$DnsNS" \
  --cert="$CERT_PATH" \
  --key="$KEY_PATH" \
  --dns-listen-port="$DNS_PORT"

# Firewall rules: redirect :53 -> $DNS_PORT (idempotent)
for proto in udp tcp; do
  if ! iptables -t nat -C PREROUTING -p "$proto" --dport 53 -j REDIRECT --to-ports "$DNS_PORT" 2>/dev/null; then
    iptables -t nat -A PREROUTING -p "$proto" --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
  fi
done

# Persist firewall rules (best-effort)
netfilter-persistent save || true

echo "✅ Slipstream setup complete."
echo "   Domain (CN): $cert"
echo "   NS Domain:   $DnsNS"
echo "   DNS listen:  $DNS_PORT (redirected from :53)"
echo "   Forwarding:  ${PORT_ARR[*]}"
echo "   Screen sesh: slipstream  (use: screen -r slipstream)"
