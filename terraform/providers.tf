terraform {
  backend "s3" {
    bucket         = "smarterise-infra-euw2"
    key            = "smarterise"
    region         = "eu-west-2"
    dynamodb_table = "smarterise-infra-lock-euw2"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.24.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "eu-west-2"
}
