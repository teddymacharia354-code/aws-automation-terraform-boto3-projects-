# Tell Terraform that this project will use the AWS provider

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Tell the AWS provider which region to use

provider "aws" {
  region = var.aws_region
}
