#!/bin/bash

# BaSH Script assumes it's running on a Debian distribution
# AWS EC2 Debian 12 AMI's use 'admin' as the default user, remember to create a key-pair in EC2 before launching

# Environment Variables sourced from Terraform EC2 Variables 
#TIMEZONE=""
#CIDR=""
#NAME_PREFIX=""
#FQDN=""
#AWSREGION=""
#ZONEID=""
#WGCIDR=""

env

# Update and Install Packages

cd /home/admin

export DEBIAN_FRONTEND=noninteractive

apt update && apt install wget \
  curl \
  git \
  unzip \
  htop \
  bzip2 \
  git \
  python3-pip \
  ca-certificates \
  gnupg \
  wireguard \
  net-tools \
  bind9-dnsutils \
  cron \
  sysstat \
  vnstat \
  software-properties-common -y

# Add Debian Non Free Repo
sudo apt-add-repository contrib non-free-firmware -y
sudo sed -i 's/Components: main/Components: main non-free non-free-firmware contrib/g' /etc/apt/sources.list.d/debian.sources
apt update

## Set timezone
sudo timedatectl set-timezone ${TIMEZONE}

## Force NAT routing and iptables masquerade on reboot (The above should do this - must fix)
sudo echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf

## Install AWS CLi for ARM64

curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip

## Allow Sphere to disable its Source Dest Check via IAM role permissions

EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
/usr/local/bin/aws ec2 modify-instance-attribute --no-source-dest-check --instance-id $EC2_INSTANCE_ID --region ${AWSREGION}
/usr/local/bin/aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=${NAME_PREFIX} --region ${AWSREGION}

## Update the private route tables of VPC to route Internet traffic via Sphere 
PRIV_TABLES="`/usr/local/bin/aws ec2 describe-route-tables --filters "Name=tag:Name,Values=${NAME_PREFIX}-private-route-table-${AWSREGION}" --query 'RouteTables[*].RouteTableId' --output text `"

## Delete default route on private subnets
for table in $PRIV_TABLES; do
  /usr/local/bin/aws ec2 delete-route --route-table-id $table --destination-cidr-block "0.0.0.0/0"; done

## Add new default route to new Sphere instance to enable Internet routing
for table in $PRIV_TABLES; do
  /usr/local/bin/aws ec2 create-route --route-table-id $table --destination-cidr-block "0.0.0.0/0" --instance-id $EC2_INSTANCE_ID; done

## Update Route53 A record for Sphere and update with new Public IP
SPHERE_PUBIP="`wget -q -O - http://169.254.169.254/latest/meta-data/public-ipv4`"
export SPHERE_PUBIP
/usr/local/bin/aws route53 change-resource-record-sets --hosted-zone-id ${ZONEID} --change-batch '{"Comment":"Update record to reflect new IP address","Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"${FQDN}","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'$SPHERE_PUBIP'"}]} }]}'

## WireGuard Setup and Config

## Get Config from SSM

CONFIG=`/usr/local/bin/aws ssm get-parameter --name /${NAME_PREFIX}/wireguardconfig --query 'Parameter.Value' --with-decryption --output text`

# Inject into /etc/wireguard/wg0.conf
echo $CONFIG | base64 -d > /etc/wireguard/wg0.conf

# Secure permissions for wireguard config
chown -R root:root /etc/wireguard/
chmod -R 770 /etc/wireguard/

## Enable and start WireGuard on Host 

sudo systemctl enable wg-quick@wg0.service
sudo systemctl daemon-reload
sudo systemctl start wg-quick@wg0

## Set Hostname and add to /etc/hosts
hostnamectl set-hostname ${FQDN}
echo "$SPHERE_PUBIP ${FQDN}" | sudo tee -a /etc/hosts
hostnamectl set-hostname "${NAME_PREFIX}" --pretty

## Raise Shields -- Iptables rules
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
sudo iptables -A INPUT -s ${CIDR} -j ACCEPT
sudo iptables -A INPUT -s ${WG0CIDR} -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p udp -m udp --dport 51820 -j ACCEPT
sudo iptables -A INPUT -j LOG --log-prefix "Dropped: " --log-level 7
sudo iptables -A INPUT -j DROP
sudo iptables -t nat -A POSTROUTING -o ens5 -s ${CIDR} -j MASQUERADE
#sudo iptables -A FORWARD -j DROP todo: prevents wg0 forwarding post boot. to fix
# Save IPTables and make persistent
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent

# Echo into Cloud INIT Log that we the Bootstrap has finished
echo "Sphere Bootstrap Complete - Rebooting to apply changes." 

# Update kernel and reboot
sudo reboot