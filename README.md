# Poor Technologists AWS NAT & WireGuard Cloud Network

# Solution Overview

![AWS_NAT](./images/aws_nat_sphere.png)

I put this simple terraform project together because I wanted an easy to manage NAT instance that I could use to connect my home network securely to my AWS VPC. This enables me to access workloads across my AWS accounts for things such as Ai and Internet of Things (IoT) projects.

I also wanted to manage the whole deployment using infrastructure code (Terraform) and version control through github, and.. after a few too many wines went down the rabbit hole of automating my deploy using AWS CodePipline and AWS CodeBuild because I could. (I will add this to the project soon)

At a high level, the terraform deploys an EC2 instance into a AWS VPC with 3 availability zones. The instance is configured to act as a NAT gateway for the private subnets in the VPC. The instance is also configured to act as a WireGuard VPN concentrator, allowing clients to connect to the VPC from anywhere in the world as well as attaching my home LAN network. 

A simple bootstrap script is used to configure the instance to act as a NAT gateway and WireGuard VPN concentrator. The bootstrap script also configures the instance to automatically start the WireGuard VPN service and perform some basic hardening of the instance. todo: add wireguard generation on first boot rather than wg0.conf injection

# Prerequisites

1. AWS Account with permissions to create resources
2. Terraform installed on your local machine
3. AWS CLI installed on your local machine
4. AWS CLI configured with your AWS account credentials
5. Basic understanding of Terraform and AWS
6. A EC2 Key Pair for SSH access to the EC2 instance
7. A Route53 public zone and domain name (This can be overriden if you do not use Route53. You will need to manually manage your DNS resources for this deployment)

# Usage Instructions:

1. Clone Repo
2. Update the terraform.tfvars file with your customisations
3. Run Terraform Plan and Apply

*WARNING* Deploying this terraform will create resources in your AWS account that may incur costs. Please review the resources created by the terraform script and ensure you understand the costs associated with them before deploying.

Recommend InfraCost.io for cost estimation before deploying. I ran this across this project and it estimated the monthly cost to be around $16 USD/month
![InfraCost](./images/aws_nat_sphere_monthlycost.png)

# Terraform References

This terraform calls on the AWS VPC Terraform module to deploy the following VPC archtecture. 

See link https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest for more details.

*WARNING* Deploying this terraform will create resources in your AWS account that may incur costs. Please review the resources created by the terraform script and ensure you understand the costs associated with them before deploying.

# Terraform High level Contents

The terraform script deploys the following resources:

VPC Module:
- VPC with 3 availability zones
- 3 public subnets
- 3 private subnets
- 1 public routing table
- 3 private routing tables
- 1 resource tagging
EC2 Module:
- 1 t4g.small EC2 instance
- 1 launch configuration for the autoscale group with a bootstrap script userdata.sh
- 1 autoscale group with min=1, max=1 instances (For auto recovery)
- 1 SSM secure parameter for the wireguard configuration file
- 1 IAM Instance Profile
- 1 IAM Role Policy for the instance profile
Security Group Module:
- 1 security group for the EC2 instance
- 1 security group rule for the WireGuard VPN service
- 1 security group rule for SSH ingress
- 1 security group rule for to allow East - West Access across the private subnets inbound to the NAT instance