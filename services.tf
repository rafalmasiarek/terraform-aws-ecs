module "service" {
  source = "./modules/service"

  for_each = var.services

  # A service using an EC2 capacity-provider strategy can otherwise reach AWS
  # before the provider is associated with the cluster and fail creation.
  depends_on = [aws_ecs_cluster_capacity_providers.this]

  cluster_id   = aws_ecs_cluster.this.id
  cluster_name = aws_ecs_cluster.this.name
  name         = "${var.name}-${each.key}"

  container_definitions = each.value.container_definitions

  task_cpu                   = try(each.value.task_cpu, null)
  task_memory                = try(each.value.task_memory, null)
  network_mode               = try(each.value.network_mode, "awsvpc")
  requires_compatibilities   = try(each.value.requires_compatibilities, ["FARGATE"])
  task_role_arn              = try(each.value.task_role_arn, null)
  execution_role_arn         = try(each.value.execution_role_arn, null)
  default_execution_role_arn = var.create_task_execution_role ? aws_iam_role.task_execution[0].arn : null
  volumes                    = try(each.value.volumes, [])

  scheduling_strategy        = try(each.value.scheduling_strategy, "REPLICA")
  desired_count              = try(each.value.desired_count, try(each.value.scheduling_strategy, "REPLICA") == "DAEMON" ? null : 1)
  launch_type                = try(each.value.launch_type, "FARGATE")
  capacity_provider_strategy = try(each.value.capacity_provider_strategy, [])

  deployment_circuit_breaker = try(each.value.deployment_circuit_breaker, null)
  deployment_controller_type = try(each.value.deployment_controller_type, null)
  enable_ecs_managed_tags    = try(each.value.enable_ecs_managed_tags, false)
  propagate_tags             = try(each.value.propagate_tags, null)
  service_connect            = try(each.value.service_connect, null)

  runtime_platform                    = try(each.value.runtime_platform, null)
  ephemeral_storage_gib               = try(each.value.ephemeral_storage_gib, null)
  pid_mode                            = try(each.value.pid_mode, null)
  ipc_mode                            = try(each.value.ipc_mode, null)
  enable_fault_injection              = try(each.value.enable_fault_injection, false)
  proxy_configuration                 = try(each.value.proxy_configuration, null)
  managed_ebs_volume                  = try(each.value.managed_ebs_volume, null)
  default_ecs_infrastructure_role_arn = var.create_ecs_infrastructure_role ? try(aws_iam_role.ecs_infrastructure[0].arn, null) : null

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
}
