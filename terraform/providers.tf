terraform {
  required_version = "~> 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.46.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.2.1"
    }
    github = {
      source = "integrations/github"
      version = "5.12.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

data "aws_caller_identity" "self" {}
data "aws_region" "current" {}