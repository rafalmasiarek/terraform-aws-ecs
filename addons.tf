# ECS cluster add-ons (see docs/addons.md). Plan-critical facts are computed
# here, at the root, where var.cluster_addons is still fully known - a value
# that crosses into the child module containing any computed value would be
# tainted to unknown and break every count-gated resource in there.

locals {
  addons_traefik = try(var.cluster_addons.traefik, null)

  # Deployment model: EC2 launch type or EC2 capacity providers -> DAEMON
  # bridge service; Fargate (or explicit REPLICA) -> replicated awsvpc.
  # Capacity detection for auto-detection of defaults.
  addons_has_ec2_capacity    = length(var.node_groups) > 0
  addons_has_fargate_capacity = length(var.fargate_capacity_providers) > 0
  addons_is_mixed            = local.addons_has_ec2_capacity && local.addons_has_fargate_capacity

  # Traefik default launch: EC2 for pure-EC2 (daemon), FARGATE otherwise.
  addons_traefik_default_launch = local.addons_has_ec2_capacity && !local.addons_has_fargate_capacity ? "EC2" : "FARGATE"
  addons_traefik_daemon = local.addons_traefik != null && (
    try(local.addons_traefik.scheduling_strategy, "DAEMON") == "DAEMON"
    && (
      try(local.addons_traefik.launch_type, local.addons_traefik_default_launch) == "EC2"
      || length(coalesce(try(local.addons_traefik.capacity_provider_strategy, null), [])) > 0
    )
  )

  addons_traefik_ingress = try(local.addons_traefik.ingress, {})

  addons_traefik_create_lb = local.addons_traefik == null || try(local.addons_traefik.enabled, true) ? try(local.addons_traefik_ingress.create_load_balancer, true) : false
  addons_traefik_nlb       = local.addons_traefik_create_lb && try(local.addons_traefik_ingress.load_balancer_type, "alb") == "nlb"
  addons_traefik_internal  = local.addons_traefik_create_lb ? try(local.addons_traefik_ingress.internal, true) : false

  # A 443 entrypoint exists when traefik manages TLS itself (ACME or manual
  # certs) or an existing LB forwards a TLS listener to the container.
  addons_traefik_entrypoint_443 = contains(["traefik", "manual"], try(local.addons_traefik.tls.managed_by, "lb")) || (!local.addons_traefik_create_lb && try(local.addons_traefik_ingress.tls_enabled, false))

  addons_traefik_routes_count = length(coalesce(try(local.addons_traefik.routes, null), []))
  addons_traefik_acme         = try(local.addons_traefik.tls.managed_by, "lb") == "traefik" && try(local.addons_traefik.tls.acme, null) != null
}

module "addons" {
  source = "./modules/addons"
  count  = var.cluster_addons != null ? 1 : 0

  cluster_id                 = aws_ecs_cluster.this.id
  cluster_name               = aws_ecs_cluster.this.name
  vpc_id                     = var.vpc_id
  cluster_security_group_id  = aws_security_group.this.id
  default_execution_role_arn = var.create_task_execution_role ? aws_iam_role.task_execution[0].arn : null
  infrastructure_role_arn    = var.infrastructure_role_arn != null ? var.infrastructure_role_arn : (var.create_infrastructure_role ? aws_iam_role.infrastructure[0].arn : null)

  cluster_addons = var.cluster_addons

  plan_facts = {
    has_ec2_capacity        = local.addons_has_ec2_capacity
    has_fargate_capacity    = local.addons_has_fargate_capacity
    is_mixed                = local.addons_is_mixed
    traefik_daemon          = local.addons_traefik_daemon
    traefik_create_lb       = local.addons_traefik_create_lb
    traefik_nlb             = local.addons_traefik_nlb
    traefik_internal        = local.addons_traefik_internal
    traefik_entrypoint_443  = local.addons_traefik_entrypoint_443
    traefik_routes_count    = local.addons_traefik_routes_count
    traefik_acme            = local.addons_traefik_acme
  }

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = var.tags
}
