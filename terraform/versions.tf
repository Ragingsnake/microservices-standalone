terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Configure AWS remote state backend values via -backend-config flags
  # or by creating a backend config file for your environment.
  backend "s3" {}
}
