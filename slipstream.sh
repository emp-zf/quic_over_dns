#!/bin/bash
# Autoscript by Mahboub Million
apt-get update && apt-get upgrade -y && apt install net-tools && apt install screen -y && apt install iptables -y

read -p "record A Domain For Certificate       : " -e -i a.domain.com cert
read -p "NS Domain        : " -e -i ns.domain.com DnsNS
read -p "Ports to forward (comma-separated, e.g. 22,443,80): " -e -i 22 PORTS

[[ Install certificate ]]

mkdir -p /root/slipstream/certs
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 \
  -nodes -keyout /root/slipstream/certs/key.pem \
  -out /root/slipstream/certs/cert.pem \
  -subj "/CN=$cert"


[[ -f /usr/local/bin/slipstream-server ]] || {
  wget https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-server-v0.0.2
  chmod +x /usr/local/bin/slipstream-server-v0.0.2
}



screen -dmS slipstream ~/slipstream-server-v0.0.2 \
  --target-address=127.0.0.1:$PORTS \
  --domain=$DnsNS \
  --cert=/root/slipstream/certs/cert.pem \
  --key=/root/slipstream/certs/key.pem \
  --dns-listen-port=5300


sudo iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
sudo iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 5300
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

