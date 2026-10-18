terraform {
  # >= 1.9: validation conditions may reference other variables (service_connect -> network_mode).
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
  }
}
