terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tagger = {
      source  = "registry.terraform.io/rafalmasiarek/tagger"
      version = ">= 0.1.0"
    }
  }
}
