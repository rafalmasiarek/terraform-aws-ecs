# Traefik create-mode ingress: ALB (L7, default) or NLB (L4 TCP passthrough).
# Existing mode (create_load_balancer = false) skips all of this - the caller
# owns the LB and only passes target group ARNs.

locals {
  traefik_ingress_cfg = try(local.traefik_cfg.ingress, {})

  traefik_lb_subnets = length(coalesce(try(local.traefik_ingress_cfg.subnets, null), [])) > 0 ? local.traefik_ingress_cfg.subnets : [for s in data.aws_subnets.vpc[0].ids : s]

  # Target type: instance targets for bridge (daemon) tasks, ip targets for
  # awsvpc (ECS rejects an ip-type TG registered with a bridge task).
  traefik_tg_target_type = local.traefik_daemon ? "instance" : "ip"
}

resource "aws_lb" "traefik" {
  count = local.addon_enabled.traefik && local.traefik_create_lb ? 1 : 0

  name               = "${var.cluster_name}-addon-traefik"
  load_balancer_type = local.traefik_nlb ? "network" : "application"
  internal           = local.traefik_internal
  subnets            = local.traefik_lb_subnets

  security_groups = concat(
    [var.cluster_security_group_id],
    coalesce(try(local.traefik_ingress_cfg.security_groups, null), []),
  )

  tags = merge(var.tags, coalesce(try(local.traefik_cfg.tags, null), {}))
}

resource "aws_lb_target_group" "traefik" {
  count = local.addon_enabled.traefik && local.traefik_create_lb ? 1 : 0

  name        = "${var.cluster_name}-addon-traefik-80"
  port        = 80
  protocol    = local.traefik_nlb ? "TCP" : "HTTP"
  vpc_id      = var.vpc_id
  target_type = local.traefik_tg_target_type

  dynamic "health_check" {
    for_each = local.traefik_nlb ? [] : [1]
    content {
      enabled             = true
      interval            = 30
      path                = "/"
      port                = "traffic-port"
      protocol            = "HTTP"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      timeout             = 5
    }
  }

  tags = merge(var.tags, coalesce(try(local.traefik_cfg.tags, null), {}))
}

resource "aws_lb_target_group" "traefik_443" {
  count = local.addon_enabled.traefik && local.traefik_create_lb && local.traefik_ep_443 ? 1 : 0

  name        = "${var.cluster_name}-addon-traefik-443"
  port        = 443
  protocol    = local.traefik_nlb ? "TCP" : "TLS"
  vpc_id      = var.vpc_id
  target_type = local.traefik_tg_target_type

  # TLS passthrough on an ALB: the listener terminates, the TG speaks TLS.
  # An NLB forwards raw TCP to the container's own TLS entrypoint.
  dynamic "health_check" {
    for_each = local.traefik_nlb ? [] : [1]
    content {
      enabled             = true
      interval            = 30
      path                = "/"
      port                = "traffic-port"
      protocol            = "HTTPS"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      timeout             = 5
    }
  }

  tags = merge(var.tags, coalesce(try(local.traefik_cfg.tags, null), {}))
}

# Listeners: always 80; 443 when the container exposes a websecure entrypoint.
# ALB: HTTP(S) listeners with host-header routing left to traefik itself
# (single backend service). NLB: plain TCP forward.
resource "aws_lb_listener" "traefik_80" {
  count = local.addon_enabled.traefik && local.traefik_create_lb ? 1 : 0

  load_balancer_arn = aws_lb.traefik[0].arn
  port              = 80
  protocol          = local.traefik_nlb ? "TCP" : "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik[0].arn
  }
}

resource "aws_lb_listener" "traefik_443" {
  count = local.addon_enabled.traefik && local.traefik_create_lb && local.traefik_ep_443 ? 1 : 0

  load_balancer_arn = aws_lb.traefik[0].arn
  port              = 443
  protocol          = local.traefik_nlb ? "TCP" : "TLS"

  # ALB TLS termination requires a certificate; traefik-managed TLS (ACME or
  # manual) never uses an ALB-terminated 443 - it is a TCP passthrough NLB or
  # the user's own LB. So a certificate is only needed for ingress.tls_enabled.
  certificate_arn = try(local.traefik_ingress_cfg.certificate_arn, null)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik_443[0].arn
  }
}

# SG rules reaching the tasks: daemon (bridge) traffic arrives at node host
# ports through the cluster SG; awsvpc traffic reaches task ENIs directly.
resource "aws_security_group_rule" "traefik_ingress_80" {
  count = local.addon_enabled.traefik && local.traefik_create_lb ? 1 : 0

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  description              = "traefik addon ingress (port 80)"
  source_security_group_id = var.cluster_security_group_id
  security_group_id        = var.cluster_security_group_id
}

resource "aws_security_group_rule" "traefik_ingress_443" {
  count = local.addon_enabled.traefik && local.traefik_create_lb && local.traefik_ep_443 ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "traefik addon ingress (port 443)"
  source_security_group_id = var.cluster_security_group_id
  security_group_id        = var.cluster_security_group_id
}
