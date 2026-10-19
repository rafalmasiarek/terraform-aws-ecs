# VPC-scoped lookups. Gated on the same predicate checks.tf uses to require
# vpc_id, so a pure-Fargate, no-LB addon set does not read the VPC at all
# (keeps the module usable where vpc_id is null).

data "aws_subnets" "vpc" {
  count = local.addons_require_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}
