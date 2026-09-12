terraform {
  # Backend s3 usa locking nativo (use_lockfile), sem DynamoDB.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Mesmo bucket do stack de Kubernetes, chave diferente: os dois states sao
  # independentes (este pode ser aplicado/destruido sem tocar no cluster).
  backend "s3" {
    bucket       = "mechanicltda-terraform-state-788516091173"
    key          = "prod/sgbd/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
