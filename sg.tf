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
# (bound on the node), awsvpc/Fargate use containerPort (task ENI) - both hit
# this same SG. Rules are tagged with the service identity so each entry is
# traceable to the service that opened it; they are destroyed with the service.
locals {
  service_port_rules = {
    for r in flatten([
      for k, v in var.services : try(v.open_task_ports, null) == null ? [] : [
        for cd in try(v.container_definitions, []) : [
          for pm in try(cd.portMappings, []) : {
            key      = "${k}:${coalesce(try(pm.hostPort, null), pm.containerPort)}:${try(pm.protocol, "tcp")}"
            port     = coalesce(try(pm.hostPort, null), pm.containerPort)
            protocol = try(pm.protocol, "tcp")
            source   = v.open_task_ports
            service  = k
          }
        ]
      ]
    ]) : r.key => r
    if r.port != 0
  }
}

resource "aws_vpc_security_group_ingress_rule" "service_ports" {
  for_each = local.service_port_rules

  cidr_ipv4         = each.value.source.source_cidr_ipv4
  cidr_ipv6         = try(each.value.source.source_cidr_ipv6, null)
  description       = "auto-opened for service ${var.name}/${each.value.service}"
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
  security_group_id = aws_security_group.this.id
  tags = merge(
    local.tagger_tags["this"],
    { "Name" = "${var.name}/${each.value.service}" },
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
  to_port = each.value.to_port
}
