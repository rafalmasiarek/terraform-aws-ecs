# Traefik create-mode ingress: ALB (L7, default) or NLB (L4 TCP passthrough).
# Existing mode (create_load_balancer = false) skips all of this - the caller
# owns the LB and only passes target group ARNs.
#
# Listeners are fully configurable via ingress.listeners (a map keyed by name).
# Each entry:
#   port            = number  (external/LB-facing port)
#   container_port  = number  (internal traefik entrypoint, default: same as port)
#   protocol        = string  (optional; defaults: NLB->TCP, ALB->HTTP/TLS)
#   certificate_arn = string  (ALB TLS termination)
#   redirect_to     = number  (optional; ALB HTTP 301 redirect to another port)
#
# Default (no listeners specified): { http = {port=80}, https = {port=443} }
# when TLS is active, or just { http = {port=80} } otherwise.

locals {
  traefik_ingress_cfg = try(local.traefik_cfg.ingress, {})

  # Same reasoning as traefik_subnets in main.tf: never index
  # data.aws_subnets.vpc when traefik is disabled (count=0 in that case).
  traefik_lb_subnets = length(coalesce(try(local.traefik_ingress_cfg.subnets, null), [])) > 0 ? local.traefik_ingress_cfg.subnets : (
    local.addon_enabled.traefik ? [for s in data.aws_subnets.vpc[0].ids : s] : []
  )

  # Target type: instance targets for bridge (daemon) tasks, ip targets for
  # awsvpc (ECS rejects an ip-type TG registered with a bridge task).
  traefik_tg_target_type = local.traefik_daemon ? "instance" : "ip"

  # Listener definitions: user-provided map or default.
  traefik_listeners = coalesce(
    try(local.traefik_ingress_cfg.listeners, null),
    merge(
      { http = { port = 80, container_port = 80 } },
      local.traefik_ep_443 ? { https = { port = 443, container_port = 443 } } : {},
    ),
  )

  # Distinct container ports -> one TG each.
  traefik_tg_ports = distinct([for l in values(local.traefik_listeners) : coalesce(l.container_port, l.port)])

  # ALB/NLB and target group names share AWS's 32-char hard limit. A long
  # cluster_name overflows it; truncate and append a hash of the full
  # intended name so distinct ports (or any other long name sharing the
  # same prefix) don't collide after truncation.
  traefik_lb_name      = "${var.cluster_name}-addon-traefik"
  traefik_lb_name_safe = length(local.traefik_lb_name) <= 32 ? local.traefik_lb_name : "${substr(local.traefik_lb_name, 0, 24)}-${substr(md5(local.traefik_lb_name), 0, 7)}"

  traefik_tg_names = {
    for p in local.traefik_tg_ports : p => "${var.cluster_name}-addon-traefik-${p}"
  }
  traefik_tg_names_safe = {
    for p, n in local.traefik_tg_names : p => length(n) <= 32 ? n : "${substr(n, 0, 24)}-${substr(md5(n), 0, 7)}"
  }
}

resource "aws_lb" "traefik" {
  count = local.addon_enabled.traefik && local.traefik_create_lb ? 1 : 0

  name               = local.traefik_lb_name_safe
  load_balancer_type = local.traefik_nlb ? "network" : "application"
  internal           = local.traefik_internal
  subnets            = local.traefik_lb_subnets

  # ALBs are always cross-zone (not configurable); this only matters for an
  # NLB, where it's off by default - a target registered in one AZ then
  # can't receive traffic that lands on another AZ's node/IP. Default true
  # so a single-task Fargate service (one AZ) is reachable through every
  # one of the NLB's AZ endpoints, not just the one it happens to run in.
  enable_cross_zone_load_balancing = coalesce(try(local.traefik_ingress_cfg.cross_zone_load_balancing, null), true)

  security_groups = concat(
    [var.cluster_security_group_id],
    coalesce(try(local.traefik_ingress_cfg.security_groups, null), []),
  )

  tags = local.tagger_tags["traefik-lb"]
}

# One target group per distinct container port.
resource "aws_lb_target_group" "traefik" {
  for_each = local.addon_enabled.traefik && local.traefik_create_lb ? { for p in local.traefik_tg_ports : p => p } : {}

  name = local.traefik_tg_names_safe[each.value]
  port = each.value
  # "TLS" is an NLB-only target group protocol - ALB (any port, including
  # 443) always terminates at the listener via certificate_arn and forwards
  # plain HTTP to the target.
  protocol    = local.traefik_nlb ? "TCP" : "HTTP"
  vpc_id      = var.vpc_id
  target_type = local.traefik_tg_target_type

  # /ping (traefik's own, enabled unconditionally - see --ping flags in
  # main.tf) rather than "/": a real route can legitimately live at "/",
  # and when redirect_to_https is on, "/" also needs to redirect - a path
  # the health check and a real route could both match can't be excluded
  # from that redirect without also exempting real traffic.
  dynamic "health_check" {
    for_each = local.traefik_nlb ? [] : [1]
    content {
      enabled             = true
      interval            = 30
      path                = "/ping"
      port                = "traffic-port"
      protocol            = "HTTP"
      healthy_threshold   = 2
      unhealthy_threshold = 3
      timeout             = 5
    }
  }

  tags = local.tagger_tags["traefik-tg-${each.value}"]
}

# One listener per entry in the listeners map.
resource "aws_lb_listener" "traefik" {
  for_each = local.addon_enabled.traefik && local.traefik_create_lb ? local.traefik_listeners : {}

  load_balancer_arn = aws_lb.traefik[0].arn
  port              = each.value.port
  protocol = coalesce(
    try(each.value.protocol, null),
    local.traefik_nlb ? "TCP" : (each.value.port == 443 ? "HTTPS" : "HTTP"),
  )

  certificate_arn = try(each.value.certificate_arn, null)

  # If redirect_to is set, do a 301 redirect instead of forwarding.
  dynamic "default_action" {
    for_each = try([each.value.redirect_to], [])
    content {
      type = "redirect"
      redirect {
        port        = default_action.value
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = try([each.value.redirect_to], []) == [] ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.traefik[coalesce(each.value.container_port, each.value.port)].arn
    }
  }

  tags = local.tagger_tags["traefik-listener-${each.key}"]
}

# SG rules: one per distinct container port (the internal ports the LB reaches).
resource "aws_security_group_rule" "traefik_ingress" {
  for_each = local.addon_enabled.traefik && local.traefik_create_lb ? { for p in local.traefik_tg_ports : p => p } : {}

  type                     = "ingress"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  description              = "${var.cluster_name}-addon-traefik: container port ${each.value}"
  source_security_group_id = var.cluster_security_group_id
  security_group_id        = var.cluster_security_group_id
}
