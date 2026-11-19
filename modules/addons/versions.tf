terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    tagger = {
      source  = "registry.terraform.io/rafalmasiarek/tagger"
      version = ">= 0.1.0"
    }
    cwquery = {
      source  = "registry.terraform.io/rafalmasiarek/cwquery"
      version = ">= 0.1.0"
    }
  }
}
