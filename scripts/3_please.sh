#!/bin/bash

# Author: BeardBenchBen
# URL: https://beardbench.isogen.io/blogpost
# BaSH script to generate 3x WireGuard keys and config files.
# Run this script with sudo or root privileges

## WireGuard Setup and Config
echo "Generating WireGuard Public and Private keys for 3x server and 3x client"
cd /etc/wireguard
umask 077

# Generate Server Side Keys & Client Side Keys
for i in {0..2}; do
  wg genkey | tee privatekey-server-wg$i | wg pubkey > publickey-server-wg$i
  wg genpsk > presharedkey-wg$i
  # Generate Client Side Keys
  wg genkey | tee privatekey-client-wg$i | wg pubkey > publickey-client-wg$i
done

# Create place holder WireGuard Configs for Server and Client

for i in {0..2}; do
  cat <<EOF > /etc/wireguard/wg$i.conf
[Interface]
Address = 10.$i.0.$((0+1))/32
ListenPort = 5182$i
PrivateKey = [PRIVATEKEY]
MTU = 1420
PostUp = iptables -t nat -A POSTROUTING -s 10.$i.0.0/24 -o ens5 -j MASQUERADE; iptables -A FORWARD -i wg$i -j ACCEPT; iptables -A FORWARD -o wg$i -j ACCEPT;
PostDown = iptables -t nat -D POSTROUTING -s 10.$i.0.0/24 -o ens5 -j MASQUERADE; iptables -D FORWARD -i wg$i -j ACCEPT; iptables -D FORWARD -o wg$i -j ACCEPT;
Table = auto

#Peer 1
[Peer]
PublicKey = [PEER_PUB_KEY]
PresharedKey = [PRE_SHARED_KEY]
AllowedIPs = 10.$i.0.$((0+2))/32
EOF
done

for i in {0..2}; do
  cat <<EOF > /home/admin/wg$i-client.conf
[Interface]
Address = 10.$i.0.$((0+2))/32
PrivateKey = [PRIVATEKEY]
MTU = 1420
DNS = 1.1.1.1
PostUp = iptables -t nat -A POSTROUTING -s 10.$i.0.0/24 -o ens5 -j MASQUERADE; iptables -A FORWARD -i wg$i -j ACCEPT; iptables -A FORWARD -o wg$i -j ACCEPT;
PostDown = iptables -t nat -D POSTROUTING -s 10.$i.0.0/24 -o ens5 -j MASQUERADE; iptables -D FORWARD -i wg$i -j ACCEPT; iptables -D FORWARD -o wg$i -j ACCEPT;
Table = auto
#Peer 1
[Peer]
PublicKey = [PEER_PUB_KEY]
PresharedKey = [PRE_SHARED_KEY]
AllowedIPs = 10.$i.0.0/24
Endpoint = [FQDN]:5182$i
PersistentKeepalive = 25
EOF
done

# Replace values - Server Config
for i in {0..2}; do
  PRIVATEKEY=$(cat /etc/wireguard/privatekey-server-wg$i)
  PUBLICKEY=$(cat /etc/wireguard/publickey-client-wg$i)
  PRESHAREDKEY=$(cat /etc/wireguard/presharedkey-wg$i)

  sed -i "s|\[PRIVATEKEY\]|$PRIVATEKEY|g" /etc/wireguard/wg$i.conf
  sed -i "s|\[PEER_PUB_KEY\]|$PUBLICKEY|g" /etc/wireguard/wg$i.conf
  sed -i "s|\[PRE_SHARED_KEY\]|$PRESHAREDKEY|g" /etc/wireguard/wg$i.conf
done

# Replace values - Client Config (Find in /home/admin)

for i in {0..2}; do
  PRIVATEKEY=$(cat /etc/wireguard/privatekey-client-wg$i)
  PUBLICKEY=$(cat /etc/wireguard/publickey-server-wg$i)
  PRESHAREDKEY=$(cat /etc/wireguard/presharedkey-wg$i)
  FQDN=$(hostname)
  sed -i "s|\[PRIVATEKEY\]|$PRIVATEKEY|g" /home/admin/wg$i-client.conf
  sed -i "s|\[PEER_PUB_KEY\]|$PUBLICKEY|g" /home/admin/wg$i-client.conf
  sed -i "s|\[PRE_SHARED_KEY\]|$PRESHAREDKEY|g" /home/admin/wg$i-client.conf
  sed -i "s|\[FQDN\]|$FQDN|g" /home/admin/wg$i-client.conf
done

# Secure permissions for wireguard configs (Configs in /home/admin are owned by root due to keys being present)
chown -R root:root /etc/wireguard/
chown -R root:root /home/admin/wg*
chmod -R 770 /etc/wireguard/
chmod -R 770 /home/admin/wg*

echo "WireGuard Config Complete - Client config is available at /home/admin/wg0-client.conf"

## Enable and start WireGuard on VPC node 
for i in {0..2}; do
sudo systemctl enable wg-quick@wg$i.service
sudo systemctl daemon-reload
sudo systemctl start wg-quick@wg$i
done

## Update Iptables to allow additonal wireguard ports
sudo iptables -D INPUT -j DROP
sudo iptables -A INPUT -p udp -m udp --dport 51821 -j ACCEPT
sudo iptables -A INPUT -p udp -m udp --dport 51822 -j ACCEPT
sudo iptables -A INPUT -j DROP
