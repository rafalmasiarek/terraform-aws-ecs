resource "aws_security_group" "this" {
  name        = "${var.name}-tasks"
  description = "ECS tasks/instances for cluster ${var.name}"
  vpc_id      = var.vpc_id

  tags = local.tagger_tags["this"]
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

# Dynamic host port mapping range used by the EC2 (bridge/host) launch type -
# irrelevant for Fargate (awsvpc gives every task its own ENI), harmless to
# leave open either way.
resource "aws_security_group_rule" "alb_ephemeral_ports" {
  count = var.alb_security_group_id != null ? 1 : 0

  type                     = "ingress"
  from_port                = 32768
  to_port                  = 61000
  protocol                 = "TCP"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.this.id
}

resource "aws_security_group_rule" "alb_health_check_port" {
  count = var.alb_security_group_id != null && var.tg_health_check_port != null && var.tg_health_check_port != "traffic-port" ? 1 : 0

  type                     = "ingress"
  from_port                = tonumber(var.tg_health_check_port)
  to_port                  = tonumber(var.tg_health_check_port)
  protocol                 = "TCP"
  description              = "ALB target-group health check"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.this.id
}

# Declarative user rules - terraform-aws-eks style. Cover bridge-mode host
# ports (bound on the node) and fixed awsvpc task ports alike, since this SG
# is attached to both.
resource "aws_vpc_security_group_ingress_rule" "custom" {
  for_each = var.task_sg_ingress_rules

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = coalesce(each.value.self, false) ? aws_security_group.this.id : each.value.referenced_security_group_id
  security_group_id            = aws_security_group.this.id
  tags = merge(
    local.tagger_tags["this"],
    { "Name" = coalesce(each.value.name, "${var.name}-tasks-${each.key}") },
    each.value.tags,
  )
  to_port = try(coalesce(each.value.to_port, each.value.from_port), null)
}

# Auto-opened service ports: per-service opt-in (open_task_ports on the root
# services entry). One rule per port mapping - bridge mode uses hostPort
# (bound on the node; a missing/0 hostPort is a dynamic host port and is
# skipped), awsvpc/Fargate use containerPort (task ENI) - both hit this same
# SG. Dual-stack sources expand to one rule per address family (the rule
# resource takes a single source selector), and identical protocol/port/source
# combinations across services are deduplicated (AWS rejects duplicate
# permissions on one SG). Rules are tagged with the contributing service
# identities so each entry is traceable; they are destroyed with the services.
locals {
  service_port_rule_entries = flatten([
    for k, v in var.services : try(v.open_task_ports, null) == null ? [] : [
      for cd in local.services_container_definitions[k] : [
        for pm in try(cd.portMappings, []) : {
          service  = k
          port     = try(v.network_mode, "awsvpc") == "bridge" ? try(pm.hostPort, 0) : try(pm.containerPort, 0)
          protocol = try(pm.protocol, "tcp")
          source   = v.open_task_ports
        }
      ]
    ]
  ])

  service_port_rules_expanded = flatten([
    for e in local.service_port_rule_entries : [
      try(e.source.source_cidr_ipv4, null) == null ? [] : [merge(e, { key = "${e.protocol}:${e.port}:ipv4:${e.source.source_cidr_ipv4}", cidr_type = "ipv4", cidr = e.source.source_cidr_ipv4 })],
      try(e.source.source_cidr_ipv6, null) == null ? [] : [merge(e, { key = "${e.protocol}:${e.port}:ipv6:${e.source.source_cidr_ipv6}", cidr_type = "ipv6", cidr = e.source.source_cidr_ipv6 })],
      try(e.source.source_security_group_id, null) == null ? [] : [merge(e, { key = "${e.protocol}:${e.port}:sg:${e.source.source_security_group_id}", cidr_type = "sg", cidr = e.source.source_security_group_id })],
    ]
  ])

  # Ellipsis groups by key - duplicate (protocol, port, source) combinations
  # across services collapse into one rule.
  service_port_rules_grouped = {
    for r in local.service_port_rules_expanded : r.key => r...
    if r.port != 0
  }

  # Custom rules that target the exact same (protocol, port, cidr) tuple as
  # an auto-opened one would collide at apply (AWS rejects duplicate SG
  # permissions). Build the same key format for single-port custom entries
  # and drop the auto-generated rule in favor of the explicit one.
  custom_ingress_port_keys = toset(concat(
    [
      for k, v in var.task_sg_ingress_rules : "${lower(coalesce(v.ip_protocol, "tcp"))}:${coalesce(v.from_port, "")}:ipv4:${v.cidr_ipv4}"
      if v.cidr_ipv4 != null && v.from_port != null
    ],
    [
      for k, v in var.task_sg_ingress_rules : "${lower(coalesce(v.ip_protocol, "tcp"))}:${coalesce(v.from_port, "")}:ipv6:${v.cidr_ipv6}"
      if v.cidr_ipv6 != null && v.from_port != null
    ],
    # self = true (the cluster's own SG) is intentionally excluded here - it
    # is never a candidate match for an external ALB/NLB source_security_group_id.
    [
      for k, v in var.task_sg_ingress_rules : "${lower(coalesce(v.ip_protocol, "tcp"))}:${coalesce(v.from_port, "")}:sg:${v.referenced_security_group_id}"
      if v.referenced_security_group_id != null && v.from_port != null
    ],
  ))

  service_port_rules = {
    for k, items in local.service_port_rules_grouped : k => items[0]
    if !contains(local.custom_ingress_port_keys, k)
  }

  service_port_rule_services = {
    for k, items in local.service_port_rules_grouped : k => distinct([for r in items : r.service])
  }
}

resource "aws_vpc_security_group_ingress_rule" "service_ports" {
  for_each = local.service_port_rules

  cidr_ipv4                    = each.value.cidr_type == "ipv4" ? each.value.cidr : null
  cidr_ipv6                    = each.value.cidr_type == "ipv6" ? each.value.cidr : null
  referenced_security_group_id = each.value.cidr_type == "sg" ? each.value.cidr : null
  description                  = "auto-opened for ${length(local.service_port_rule_services[each.key]) == 1 ? "service " : "services "}${var.name}/${join(",", local.service_port_rule_services[each.key])}"
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = each.value.protocol
  security_group_id            = aws_security_group.this.id
  tags = merge(
    local.tagger_tags["this"],
    { "Name" = "${var.name}/${join(",", local.service_port_rule_services[each.key])}" },
  )
}

resource "aws_vpc_security_group_egress_rule" "custom" {
  for_each = var.task_sg_egress_rules

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  description                  = each.value.description
  from_port                    = try(coalesce(each.value.from_port, each.value.to_port), null)
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = coalesce(each.value.self, false) ? aws_security_group.this.id : each.value.referenced_security_group_id
  security_group_id            = aws_security_group.this.id
  tags = merge(
    local.tagger_tags["this"],
    { "Name" = coalesce(each.value.name, "${var.name}-tasks-${each.key}") },
    each.value.tags,
  )
  # Unlike the ingress rule resource, egress does not default to_port to
  # from_port - apply the same fallback so single-port rules work.
  to_port = try(coalesce(each.value.to_port, each.value.from_port), null)
}
