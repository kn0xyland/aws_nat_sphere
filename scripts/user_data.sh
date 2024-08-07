#!/bin/bash

# BaSH Script assumes it's running on a Debian distribution
# AWS EC2 Debian 12 AMI's use 'admin' as the default user, remember to create a key-pair in EC2 before launching
# Check README.md for more information

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

## Enable IP Forwarding
echo "Updating Kernel to allow IP Forwarding..."

sudo echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf

## Install AWS CLi
echo "Install latest AWSCLi..."
if [[ $(uname -m) == "x86_64" ]]; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
elif [[ $(uname -m) == "aarch64" ]]; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
else
  echo "Unsupported architecture"
  exit 1
fi
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip

## Allow Sphere to disable its Source Dest Check via IAM role permissions on boot

echo "Disabling EC2 Instance Source Dest Check to permit routing through Sphere instance..."

EC2_INSTANCE_ID="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
/usr/local/bin/aws ec2 modify-instance-attribute --no-source-dest-check --instance-id $EC2_INSTANCE_ID --region ${AWSREGION}
/usr/local/bin/aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=${NAME_PREFIX} --region ${AWSREGION}

## Discover private route tables
PRIV_TABLES="`/usr/local/bin/aws ec2 describe-route-tables --filters 'Name=tag:Name,Values=${NAME_PREFIX}-private-route-table-${AWSREGION}' --query 'RouteTables[*].RouteTableId' --output text`"

echo "Updating Private Route Tables with new default route to Sphere instance..."

## Check if 0.0.0.0/0 exists in private route tables and delete if present
for table in $PRIV_TABLES; do
  default_route="$(/usr/local/bin/aws ec2 describe-route-tables --route-table-ids $table --query 'RouteTables[*].Routes[?DestinationCidrBlock==`0.0.0.0/0`]' --output text)"
  if [[ -z "$default_route" ]]; then
    echo "0.0.0.0/0 route does not exist in private route table. Exiting..."
  else
      /usr/local/bin/aws ec2 delete-route --route-table-id $table --destination-cidr-block '0.0.0.0/0'
  fi
done

## Add new default route to Sphere instance to enable NAT routing for private subnets
for table in $PRIV_TABLES; do
  /usr/local/bin/aws ec2 create-route --route-table-id $table --destination-cidr-block "0.0.0.0/0" --instance-id $EC2_INSTANCE_ID; 
done

## Update Route53
echo "Updating Route53 A record for ${FQDN} with new Public IP..."

SPHERE_PUBIP="`wget -q -O - http://169.254.169.254/latest/meta-data/public-ipv4`"
export SPHERE_PUBIP
/usr/local/bin/aws route53 change-resource-record-sets --hosted-zone-id ${ZONEID} --change-batch '{"Comment":"Update record to reflect new IP address","Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"${FQDN}","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'$SPHERE_PUBIP'"}]} }]}'

## WireGuard Setup and Config
echo "Generating WireGuard Public and Private keys.."
cd /etc/wireguard
umask 077
# Generate Server Side Keys
wg genkey | tee privatekey-server | wg pubkey > publickey-server
wg genpsk > presharedkey
# Generate Client Side Keys
wg genkey | tee privatekey-client | wg pubkey > publickey-client

cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = [PRIVATEKEY]
MTU = 1420
PostUp = iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o ens5 -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT;
PostDown = iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o ens5 -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT;
Table = auto

#Peer 1
[Peer]
PublicKey = [PEER_PUB_KEY]
PresharedKey = [PRE_SHARED_KEY]
AllowedIPs = 10.10.0.2/32
EOF

cat <<EOF > /home/admin/wg0-client.conf
[Interface]
Address = 10.10.0.2/32
PrivateKey = [PRIVATEKEY_CLIENT]
DNS = 1.1.1.1
MTU = 1420
PostUp = iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT;
PostDown = iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o eth0 -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT;

[Peer]
PublicKey = [PUBLICKEY_SERVER]
PresharedKey = [PRE_SHARED_KEY]
AllowedIPs = 0.0.0.0/0
Endpoint = [FQDN]:51820
PersistentKeepalive = 25
EOF

# Replace values in wg0.conf - Server Config
PRIVATEKEY=$(cat privatekey-server)
PUBLICKEY=$(cat publickey-client)
PRESHAREDKEY=$(cat presharedkey)

sed -i "s|\[PRIVATEKEY\]|$PRIVATEKEY|g" /etc/wireguard/wg0.conf
sed -i "s|\[PEER_PUB_KEY\]|$PUBLICKEY|g" /etc/wireguard/wg0.conf
sed -i "s|\[PRE_SHARED_KEY\]|$PRESHAREDKEY|g" /etc/wireguard/wg0.conf

NETWORK_ADDRESS=$(echo ${WG0CIDR} | cut -d'/' -f1)
SUBNET_MASK=$(echo ${WG0CIDR} | cut -d'/' -f2)

FIRST_IP=$(echo $NETWORK_ADDRESS | awk -F. '{print $1"."$2"."$3"."$4+1}')
SECOND_IP=$(echo $NETWORK_ADDRESS | awk -F. '{print $1"."$2"."$3"."$4+2}')

sed -i "s|Address = .*|Address = $FIRST_IP/$SUBNET_MASK|" /etc/wireguard/wg0.conf
sed -i "s|AllowedIPs = .*|AllowedIPs = $SECOND_IP/$SUBNET_MASK|" /etc/wireguard/wg0.conf

# Replace values in wg0-client.conf - Client Config located in /home/admin 

PRIVATEKEY=$(cat privatekey-client)
PUBLICKEY=$(cat publickey-server)
PRESHAREDKEY=$(cat presharedkey)

sed -i "s|\[PRIVATEKEY_CLIENT\]|$PRIVATEKEY|g" /home/admin/wg0-client.conf
sed -i "s|\[PUBLICKEY_SERVER\]|$PUBLICKEY|g" /home/admin/wg0-client.conf
sed -i "s|\[PRE_SHARED_KEY\]|$PRESHAREDKEY|g" /home/admin/wg0-client.conf
sed -i "s|\[FQDN\]|${FQDN}|g" /home/admin/wg0-client.conf

sed -i "s|Address = .*|Address = $SECOND_IP/$SUBNET_MASK|" /home/admin/wg0-client.conf

# Secure permissions for wireguard config
chown -R root:root /etc/wireguard/
chmod -R 770 /etc/wireguard/

echo "WireGuard Config Complete - Client config is available at /home/admin/wg0-client.conf..."

# Define variables
CONFIG_FILE_PATH="/etc/wireguard/wg0.conf"
ENCODED_CONFIG=$(base64 -w 0 "$CONFIG_FILE_PATH")
FULL_PARAMETER_NAME="/${NAME_PREFIX}/wg0"

# Check AWS SSM Parameter Store for existing parameter
if ! /usr/local/bin/aws ssm get-parameter --name "$FULL_PARAMETER_NAME" >/dev/null 2>&1; then
  # If the parameter does not exist, create it
  /usr/local/bin/aws ssm put-parameter --name "$FULL_PARAMETER_NAME" --value "$ENCODED_CONFIG" --type SecureString --overwrite
else
  # If the parameter already exists, restore the configuration file wg0
  echo "SSM parameter $FULL_PARAMETER_NAME already exists. Assume recovery & restore to $CONFIG_FILE_PATH"
  # Inject into /etc/wireguard/wg0.conf
  RESTORE_CONFIG=`/usr/local/bin/aws ssm get-parameter --name "/${NAME_PREFIX}/wg0" --query 'Parameter.Value' --with-decryption --output text`
  rm -rf /etc/wireguard/p*
  echo $RESTORE_CONFIG | base64 -d > $CONFIG_FILE_PATH
fi

## Enable and start WireGuard on Host 
sudo systemctl enable wg-quick@wg0.service
sudo systemctl daemon-reload
sudo systemctl start wg-quick@wg0

echo "End of WireGuard Section..."

## Set Hostname and add to /etc/hosts
echo "Setting Hostname to ${FQDN}..."

hostnamectl set-hostname ${FQDN}
echo "$SPHERE_PUBIP ${FQDN}" | sudo tee -a /etc/hosts
hostnamectl set-hostname "${NAME_PREFIX}" --pretty

## Raise Shields -- Iptables rules
echo "Enabling basic iptabes firewall ruleset for IPv4..."

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

# Save IPTables and make persistent
echo "Saving IPTables rules and making them persistent..."

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent

# Echo into Cloud INIT Log that we the Bootstrap has finished
echo "Sphere Bootstrap Complete - Rebooting to apply package changes." 
sudo reboot