variable "myip" {
  description = "Set your public address to secure access to your IP"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for resources on AWS"
  default     = ""
}

variable "security_group_id" {
  description = "Security Group ID"
  default     = ""
}

variable "awsregion" {
  description = "AWS region"
  type        = string
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = []
}