terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1"
    }
    http = {
      source  = "terraform-aws-modules/http"
      version = ">= 2.4"
    }

  }

   ##  AWS s3 Backend for storing terraform state - Recommended - ensure bucket versioning is enabled if using this for production
   backend "s3" {
     bucket = "testing-ec2-terraform"
     region = "ap-southeast-2" 
     key    = "terraform.tfstate"
   }
}
