terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {}   # configured via -backend-config in CI
}

provider "aws" {
  region = var.aws_region
}