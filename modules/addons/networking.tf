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

# NAT/IGW check on the default subnet pool, for the assign_public_ip default
# below. By route_table_id (always matches), not subnet_id - a subnet with no
# explicit association falls back to the VPC's main table, which aws_route_table's
# subnet_id lookup does not resolve on its own.
data "aws_route_tables" "vpc" {
  count = local.addons_require_vpc ? 1 : 0

  vpc_id = var.vpc_id
}

data "aws_route_table" "vpc_rt" {
  for_each = local.addons_require_vpc ? toset(data.aws_route_tables.vpc[0].ids) : toset([])

  route_table_id = each.value
}

locals {
  default_main_route_table = one([
    for rt in data.aws_route_table.vpc_rt : rt if anytrue([for a in rt.associations : a.main])
  ])

  default_subnet_route_table = {
    for s in(local.addons_require_vpc ? data.aws_subnets.vpc[0].ids : []) : s => coalesce(
      one([for rt in data.aws_route_table.vpc_rt : rt if anytrue([for a in rt.associations : try(a.subnet_id, null) == s])]),
      local.default_main_route_table,
    )
  }

  default_subnets_have_nat_egress = anytrue([
    for s, rt in local.default_subnet_route_table : anytrue([
      for r in rt.routes : r.cidr_block == "0.0.0.0/0" && try(r.nat_gateway_id, "") != ""
    ])
  ])

  default_subnets_have_igw_route = length(local.default_subnet_route_table) > 0 && alltrue([
    for s, rt in local.default_subnet_route_table : anytrue([
      for r in rt.routes : r.cidr_block == "0.0.0.0/0" && can(regex("^igw-", coalesce(r.gateway_id, "")))
    ])
  ])

  # Public (IGW route) and no NAT -> the only case a public IP actually helps.
  addon_assign_public_ip_default = local.addons_require_vpc && local.default_subnets_have_igw_route && !local.default_subnets_have_nat_egress
}
