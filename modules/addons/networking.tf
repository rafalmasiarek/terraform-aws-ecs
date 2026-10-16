# VPC-scoped lookups. Gated on plan facts so a pure-Fargate, no-LB addon set
# does not read the VPC at all (keeps the module usable where vpc_id is null).

locals {
  # Every awsvpc preset (daemon traefik included - it still needs the VPC
  # data for its LB) plus the Fargate presets that default their subnets to
  # the whole VPC.
  vpc_data_needed = anytrue([
    local.addon_enabled.traefik,
    local.addon_enabled.opentelemetry,
    local.addon_enabled.cloudwatch_agent,
    local.addon_enabled.fluent_bit,
    local.addon_enabled.blackbox_exporter,
  ])
}

data "aws_vpc" "this" {
  count = local.vpc_data_needed ? 1 : 0

  id = var.vpc_id
}

data "aws_subnets" "vpc" {
  count = local.vpc_data_needed ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}
