terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "roman-eks-terraform-state"
    key          = "eks/terraform.tfstate" #file path in bucket where state is stored
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}