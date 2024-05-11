provider "aws" {
  region = var.awsregion
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                 = "${var.name_prefix}-vpc"
  cidr                 = var.cidr
  azs                  = var.azs
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_dns_hostnames = true
  private_route_table_tags = {
    Name = "${var.name_prefix}-private-route-table-${var.awsregion}"
  }
  private_subnet_tags_per_az = {
    for az in var.azs : az => {
      Name = "${var.name_prefix}-private-subnet-${az}"
    }
  }
  public_subnet_tags_per_az = {
    for az in var.azs : az => {
      Name = "${var.name_prefix}-public-subnet-${az}"
    }
  }
  
  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name   = basename(path.cwd)
  region = var.awsregion
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(    
    var.default_tags,    
    {     
      Blueprint  = local.name
    },  
  )
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = ["${var.name_prefix}-vpc"]
  }

  depends_on = [
      module.vpc
  ]
}

data "aws_subnet" "public_subnet_az_a" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-public-subnet-${local.azs[0]}"]
  }
  depends_on = [
      module.vpc
  ]
}

resource "aws_security_group" "sphere-sg" {
  name        = "${var.name_prefix}-SG"
  description = "Main security group"
  vpc_id = data.aws_vpc.selected.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }
  depends_on = [
      module.vpc
  ]
}

resource "aws_ssm_parameter" "sphere_parameter" {
  name        = "/${var.name_prefix}/wireguardconfig"
  description = "${var.name_prefix} wireguard wg0 conf"
  type        = "SecureString"
  value       = base64encode(file("${path.module}/wg0.conf"))

  lifecycle {
    create_before_destroy = true
  }
}

module "ec2" {
  source = "./modules/ec2"
  depends_on = [ aws_security_group.sphere-sg ]

  security_group_id           = aws_security_group.sphere-sg.id
  name_prefix                 = var.name_prefix
  instance_type               = var.instance_type
  root_block_device           = var.root_block_device
  ebs_block_device            = var.ebs_block_device
  deploy_sphere               = var.deploy_sphere
  zoneid                      = var.zoneid
  aws_account_id              = var.aws_account_id
  kms_id                      = var.kms_id
  kms_policy                  = var.kms_policy
  key_name                    = var.key_name
  enable_monitoring           = var.enable_monitoring
  enabled_metrics             = var.enabled_metrics
  metrics_granularity         = var.metrics_granularity
  associate_public_ip_address = var.associate_public_ip_address
  awsregion                   = var.awsregion
  min_size                    = var.min_size
  max_size                    = var.max_size
  desired_capacity            = var.desired_capacity
  image_id                    = var.image_id
  default_tags                = var.default_tags
  placement_tenancy           = var.placement_tenancy
  service_linked_role_arn     = var.service_linked_role_arn
  cidr                        = var.cidr
  wg0cidr                     = var.wg0cidr
  timezone                    = var.timezone
  fqdn                        = var.fqdn
  public_subnets              = var.public_subnets
  vpc_ident                   = data.aws_subnet.public_subnet_az_a.id
}

module "securitygroups" {
  source = "./modules/securitygroups"

  myip              = var.myip
  security_group_id = aws_security_group.sphere-sg.id
  awsregion         = var.awsregion
  name_prefix       = var.name_prefix
  private_subnets   = var.private_subnets
}