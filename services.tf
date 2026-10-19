locals {
  services_has_ec2_capacity     = length(var.node_groups) > 0
  services_has_fargate_capacity = length(var.fargate_capacity_providers) > 0
  services_is_mixed             = local.services_has_ec2_capacity && local.services_has_fargate_capacity

  # FARGATE always. launch_type is ForceNew; auto-flipping to EC2 on node_groups
  # presence would destroy/recreate services. Override per-service for EC2.
  services_default_launch_type = "FARGATE"

  # Used only when capacity_provider_strategy is set (both compatibilities,
  # scheduler picks per task) - the plain-launch_type default below instead
  # matches the resolved launch_type 1:1, as AWS requires.
  services_default_requires_compatibilities = concat(
    local.services_has_ec2_capacity ? ["EC2"] : [],
    local.services_has_fargate_capacity ? ["FARGATE"] : [],
  )

  # containerPort = null -> stable hash-derived port in this range, instead
  # of callers all guessing the same number. Hash, not `random` provider:
  # the SG rules below key for_each on the port, which must be known at plan.
  services_random_port_min = 20000
  services_random_port_max = 60000

  services_container_definitions = {
    for sk, sv in var.services : sk => [
      for ci, c in try(sv.container_definitions, []) : merge(c, {
        portMappings = [
          for pi, pm in try(c.portMappings, []) : merge(pm, {
            containerPort = coalesce(try(pm.containerPort, null), (
              parseint(substr(md5("${sk}::${ci}::${pi}"), 0, 8), 16) %
              (local.services_random_port_max - local.services_random_port_min)
            ) + local.services_random_port_min)
          })
        ]
      })
    ]
  }
}

module "service" {
  source = "./modules/service"

  for_each = var.services

  # A service using an EC2 capacity-provider strategy can otherwise reach AWS
  # before the provider is associated with the cluster and fail creation.
  depends_on = [aws_ecs_cluster_capacity_providers.this]

  cluster_id   = aws_ecs_cluster.this.id
  cluster_name = aws_ecs_cluster.this.name
  name         = "${var.name}-${each.key}"

  # Pass a literal true, not a derived check against cluster_security_group_id
  # (unknown on a fresh apply) - see auto_ingress_enabled in
  # modules/service/variables.tf.
  cluster_security_group_id = aws_security_group.this.id
  auto_ingress_enabled      = true

  container_definitions = local.services_container_definitions[each.key]

  task_cpu     = try(each.value.task_cpu, null)
  task_memory  = try(each.value.task_memory, null)
  network_mode = try(each.value.network_mode, "awsvpc")
  requires_compatibilities = try(each.value.requires_compatibilities, length(try(each.value.capacity_provider_strategy, [])) > 0 ? (
    local.services_default_requires_compatibilities
    ) : (
    [try(each.value.launch_type, local.services_default_launch_type)]
  ))
  task_role_arn              = try(each.value.task_role_arn, null)
  execution_role_arn         = try(each.value.execution_role_arn, null)
  default_execution_role_arn = var.create_task_execution_role ? aws_iam_role.task_execution[0].arn : null
  volumes                    = try(each.value.volumes, [])
  infrastructure_role_arn    = local.ecs_infrastructure_role_arn

  scheduling_strategy        = try(each.value.scheduling_strategy, "REPLICA")
  desired_count              = try(each.value.desired_count, try(each.value.scheduling_strategy, "REPLICA") == "DAEMON" ? null : 1)
  launch_type                = try(each.value.launch_type, local.services_default_launch_type)
  capacity_provider_strategy = try(each.value.capacity_provider_strategy, [])

  deployment_circuit_breaker = try(each.value.deployment_circuit_breaker, null)
  deployment_controller_type = try(each.value.deployment_controller_type, null)
  enable_ecs_managed_tags    = try(each.value.enable_ecs_managed_tags, var.use_tagger)
  propagate_tags             = try(each.value.propagate_tags, var.use_tagger ? "SERVICE" : null)
  service_connect            = try(each.value.service_connect, null)

  runtime_platform                    = try(each.value.runtime_platform, null)
  ephemeral_storage_gib               = try(each.value.ephemeral_storage_gib, null)
  pid_mode                            = try(each.value.pid_mode, null)
  ipc_mode                            = try(each.value.ipc_mode, null)
  enable_fault_injection              = try(each.value.enable_fault_injection, false)
  proxy_configuration                 = try(each.value.proxy_configuration, null)
  managed_ebs_volume                  = try(each.value.managed_ebs_volume, null)
  default_ecs_infrastructure_role_arn = local.ecs_infrastructure_role_arn

  task_execution_role = try(each.value.task_execution_role, null)
  task_role           = try(each.value.task_role, null)

  deployment_maximum_percent         = try(each.value.deployment_maximum_percent, 200)
  deployment_minimum_healthy_percent = try(each.value.deployment_minimum_healthy_percent, 100)
  health_check_grace_period_seconds  = try(each.value.health_check_grace_period_seconds, null)
  enable_execute_command             = try(each.value.enable_execute_command, false)
  wait_for_steady_state              = try(each.value.wait_for_steady_state, false)
  force_new_deployment               = try(each.value.force_new_deployment, false)

  load_balancer = try(each.value.load_balancer, [])

  # Falls through to null (not a half-built object) when the caller omits
  # network_configuration entirely - modules/service's own validation then
  # reports a clear error instead of a low-level "attribute not found" here.
  network_configuration = try(each.value.network_mode, "awsvpc") == "awsvpc" && try(each.value.network_configuration, null) != null ? {
    subnets = each.value.network_configuration.subnets
    security_groups = concat(
      [aws_security_group.this.id],
      try(each.value.network_configuration.security_groups, []),
    )
    assign_public_ip = try(each.value.network_configuration.assign_public_ip, false)
  } : null

  service_registries         = try(each.value.service_registries, [])
  placement_constraints      = try(each.value.placement_constraints, [])
  ordered_placement_strategy = try(each.value.ordered_placement_strategy, [])

  autoscaling_enabled        = try(each.value.autoscaling_enabled, false)
  autoscaling_min_capacity   = try(each.value.autoscaling_min_capacity, 1)
  autoscaling_max_capacity   = try(each.value.autoscaling_max_capacity, 2)
  cpu_target_tracking        = try(each.value.cpu_target_tracking, 70)
  memory_target_tracking     = try(each.value.memory_target_tracking, null)
  scale_in_cooldown_seconds  = try(each.value.scale_in_cooldown_seconds, 300)
  scale_out_cooldown_seconds = try(each.value.scale_out_cooldown_seconds, 60)

  alb_target_tracking           = try(each.value.alb_target_tracking, null)
  custom_metric_target_tracking = try(each.value.custom_metric_target_tracking, null)
  scheduled_actions             = try(each.value.scheduled_actions, [])

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = var.tags
  origin_module  = "service"
}
