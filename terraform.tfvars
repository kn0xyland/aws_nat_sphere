## My Environment (Please update to suit your environment needs)
name_prefix        = "Sphere"              # Name your deployment
myip               = "1.1.1.1/32"          # Your Public IP address for Security Group/Firewall Rules
deploy_sphere      = "1"                   # Set to 0 to prevent EC2 NAT Instance deployment but still deploy VPC
awsregion          = "ap-southeast-4"      # Preferred AWS Region
aws_account_id     = "123456789012"        # AWS Account ID
timezone           = "Australia/Melbourne" # Your Timezone

# VPC Configuration (Update Region and CIDRs to suit your needs)
cidr               = "172.99.0.0/16"
private_subnets    = ["172.99.64.0/20", "172.99.80.0/20", "172.99.96.0/20"]
public_subnets     = ["172.99.128.0/20", "172.99.144.0/20", "172.99.160.0/20"]
azs                = ["ap-southeast-4a", "ap-southeast-4b", "ap-southeast-4c"]

# WireGuard Configuration
wg0cidr            = "10.10.0.0/24"

# Route53 Configuration
zoneid             = "YOURZONEID"
fqdn               = "nat.yourdomain.com"

## EC2 NAT Instance Configuration
associate_public_ip_address = true 
instance_type               = "t4g.small"             # t4g.small is the smallest ARM/Gravitron instance type
image_id                    = "ami-00cb428b7422c80b6" # Debian 12 arm AMI ID. Grab your regions from here https://wiki.debian.org/Cloud/AmazonEC2Image/Bookworm
key_name                    = "your-key"              # Your SSH Key Pair
enable_monitoring           = false
# To Encrypt EBS unhash and replace with your KMS key and policy -- todo: add ability to encrypt root block device
#kms_id                     = "arn:aws:kms::123456789012:key/<kms-key-id>"
#kms_policy                 = "arn:aws:iam::123456789012:policy/<kms-policy-name>"
max_size                    = "1"
min_size                    = "1"
desired_capacity            = "1"
root_block_device           = [{"volume_type" : "gp3", "volume_size" : "10", "iops" : "3000", "delete_on_termination" : "true" }]
default_tags = {
  Project     = "Sphere NAT Infra Code"
  Contact     = "youremail@gmail.com"
}