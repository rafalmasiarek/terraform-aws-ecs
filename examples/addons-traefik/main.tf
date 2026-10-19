# Traefik add-on example.
#
# Basic: traefik = {} — daemon on EC2 (or 2 replicas on Fargate) + internal ALB.
# Expert variants are commented below.

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.0" }
  }
}

provider "aws" { region = "eu-central-1" }

module "ecs" {
  source = "../.."

  name   = "demo"
  vpc_id = var.vpc_id

  node_groups = {
    nodes = {
      instance_type               = "m5.large"
      subnet_ids                  = var.subnet_ids
      min_size                    = 1
      max_size                    = 2
      desired_capacity            = 1
      associate_public_ip_address = true
    }
  }

  cluster_addons = {
    # ---- basic ----------------------------------------------------------
    traefik = {}

    # ---- expert: internet-facing ALB with LB-terminated TLS -------------
    # traefik = {
    #   ingress = {
    #     internal        = false
    #     tls_enabled     = true
    #     certificate_arn = aws_acm_certificate.app.arn
    #   }
    #   routes = [
    #     { name = "app", rule = "Host(`app.example.com`)", service = "demo-app" },
    #   ]
    # }

    # ---- expert: ACME Let's Encrypt (DNS-01, Route53) --------------------
    # traefik = {
    #   tls = {
    #     managed_by = "traefik"
    #     acme = {
    #       email        = "ops@example.com"
    #       dns_provider = "route53"
    #       storage      = { type = "efs", filesystem_id = "fs-…" }
    #     }
    #   }
    # }

    # ---- expert: manual certificates (SNI, many domains) -----------------
    # traefik = {
    #   tls = {
    #     managed_by             = "manual"
    #     certificates_directory = "/etc/traefik/certs"
    #     storage                = { type = "efs", filesystem_id = "fs-…" }
    #   }
    # }

    # ---- expert: existing load balancer ----------------------------------
    # traefik = {
    #   ingress = {
    #     create_load_balancer = false
    #     target_group_arn     = aws_lb_target_group.yours.arn
    #   }
    # }
  }
}

output "traefik_alb_dns" {
  value = module.ecs.addons.traefik.load_balancer_dns_name
}
