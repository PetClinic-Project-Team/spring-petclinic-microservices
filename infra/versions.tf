terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "petclinic-tfstate-989800606347"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
