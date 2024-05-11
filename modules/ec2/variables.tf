variable "min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
}

variable "max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
}

variable "name_prefix" {
  description = "Name prefix for resources on AWS"
  default     = ""
}

variable "security_group_id" {
  description = "Security group ID to associate with the EC2 instances"
  type        = string
}

variable "awsregion" {
  description = "AWS region"
  type        = string
}

variable "image_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
}

variable "root_block_device" {
  description = "Customize details about the root block device of the instance. This is a list of maps, where each map should contain \"volume_type\", \"volume_size\", \"iops\" and \"delete_on_termination\""
  type        = list(any)
  default     = [{"volume_type" : "gp3", "volume_size" : "10", "iops" : "3000", "delete_on_termination" : "true" }]
}

variable "ebs_block_device" {
  description = "Additional EBS block devices to attach to the instance. This is a list of maps, where each map should contain \"device_name\", \"snapshot_id\", \"volume_type\", \"volume_size\", \"iops\", \"delete_on_termination\" and \"encrypted\""
  type        = list(any)
  default     = []
}

variable "deploy_sphere" {
  description = "Deploys Sphere as NAT and WireGuard Instance"
  default     = "1"
}

variable "zoneid" {
  description = "Existing Route53 Zone ID"
  type        = string
  default     = ""
}

variable "default_tags" {
  type = map(string)
}

variable "instance_type" {
  description = "Instance Size"
  type        = string
  default     = ""
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "169370194631"
}

variable "kms_id" {
  description = "KMS Account Key ARN"
  type        = string
  default     = ""
}

variable "kms_policy" {
  description = "KMS Policy ARN"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "The key pair name that should be used for the instance"
  default     = ""
}

variable "enable_monitoring" {
  description = "Enables/disables detailed monitoring. This is disabled by default."
  type        = bool
  default     = false
}

variable "ebs_optimized" {
  description = "If true, the launched EC2 instance will be EBS-optimized."
  type        = bool
  default     = true
}

variable "associate_public_ip_address" {
  description = "Associate a public ip address with an instance in a VPC. Default is true"
  type        = bool
  default     = true
}

variable "placement_tenancy" {
  description = "The tenancy of the instance. Valid values are \"default\" or \"dedicated\", see AWS's Create Launch Configuration for more details"
  default     = "default"
}

variable "metrics_granularity" {
  description = "The granularity to associate with the metrics to collect. The only valid value is 1Minute. Default is 1Minute."
  default     = "1Minute"
}
variable "enabled_metrics" {
  description = "A list of metrics to collect. The allowed values are GroupMinSize, GroupMaxSize, GroupDesiredCapacity, GroupInServiceInstances, GroupPendingInstances, GroupStandbyInstances, GroupTerminatingInstances, GroupTotalInstances."
  type        = list(any)
  default     = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances", ]
}

variable "service_linked_role_arn" {
  description = "The ARN of the service-linked role that the ASG will use to call other AWS services"
  default     = ""
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR"
  type        = string
  default     = ""
}

variable "wg0cidr" {
  description = "The CIDR top use for the WireGuard Network"
  type        = string
  default     = ""
}

variable "timezone" {
  description = "Timezone "
  type        = string
  default     = "Australia/Melbourne"
}

variable "fqdn" {
  description = "The FQDN for the instance eg natrouter.mydomain.io"
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "A list of one or more availability zones for the group."
  type        = list(any)
  default     = [ "ap-southeast-2a" ]
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "vpc_ident" {
  description = "Hairpin Subnet"
  type        = string
}