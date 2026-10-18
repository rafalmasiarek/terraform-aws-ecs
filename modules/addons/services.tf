# One ECS service per enabled preset. Traefik is special-cased (LB wiring,
# daemon model, TLS volumes); the remaining presets follow a common shape.

module "traefik_service" {
  source = "../service"
  count  = local.addon_enabled.traefik ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-traefik"

  container_definitions = [local.traefik_container]

  task_cpu    = local.traefik_task_cpu
  task_memory = local.traefik_task_memory

  network_mode             = local.traefik_daemon ? "bridge" : "awsvpc"
  requires_compatibilities = local.traefik_compat
  scheduling_strategy      = local.traefik_daemon ? "DAEMON" : "REPLICA"

  task_role_arn              = local.traefik_task_role_arn
  execution_role_arn         = local.traefik_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = local.traefik_volumes

  desired_count              = local.traefik_daemon ? null : try(local.traefik_cfg.desired_count, 2)
  launch_type                = local.traefik_daemon ? "EC2" : try(local.traefik_cfg.launch_type, "FARGATE")
  capacity_provider_strategy = coalesce(try(local.traefik_cfg.capacity_provider_strategy, null), [])

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 30
  enable_execute_command             = true
  wait_for_steady_state              = false
  force_new_deployment               = try(local.traefik_cfg.force_new_deployment, false)

  load_balancer = local.traefik_load_balancers

  network_configuration = local.traefik_daemon ? null : {
    subnets          = local.traefik_subnets
    security_groups  = concat([var.cluster_security_group_id], coalesce(try(local.traefik_cfg.security_groups, null), []))
    assign_public_ip = false
  }

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.traefik_cfg.tags, null), {}))
}

module "opentelemetry_service" {
  source = "../service"
  count  = local.addon_enabled.opentelemetry ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-opentelemetry"

  container_definitions = [local.otel_container]

  task_cpu    = try(local.otel_cfg.task_cpu, 512)
  task_memory = try(local.otel_cfg.task_memory, 512)

  network_mode             = "awsvpc"
  requires_compatibilities = local.addon_default_compat

  task_role_arn              = local.otel_task_role_arn
  execution_role_arn         = local.otel_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = coalesce(try(local.otel_cfg.volumes, null), [])

  desired_count              = try(local.otel_cfg.desired_count, 1)
  launch_type                = try(local.otel_cfg.launch_type, local.addon_default_launch)
  capacity_provider_strategy = coalesce(try(local.otel_cfg.capacity_provider_strategy, null), [])

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  wait_for_steady_state              = false

  network_configuration = {
    subnets          = length(coalesce(try(local.otel_cfg.subnets, null), [])) > 0 ? local.otel_cfg.subnets : [for s in data.aws_subnets.vpc[0].ids : s]
    security_groups  = concat([var.cluster_security_group_id], coalesce(try(local.otel_cfg.security_groups, null), []))
    assign_public_ip = false
  }

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.otel_cfg.tags, null), {}))
}

module "cloudwatch_agent_service" {
  source = "../service"
  count  = local.addon_enabled.cloudwatch_agent ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-cloudwatch-agent"

  container_definitions = [local.cwa_container]

  task_cpu    = try(local.cwa_cfg.task_cpu, 128)
  task_memory = try(local.cwa_cfg.task_memory, 64)

  network_mode             = "awsvpc"
  requires_compatibilities = local.addon_default_compat

  task_role_arn              = local.cwa_task_role_arn
  execution_role_arn         = local.cwa_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = coalesce(try(local.cwa_cfg.volumes, null), [])

  desired_count              = 1
  launch_type                = local.addon_default_launch
  capacity_provider_strategy = []

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  wait_for_steady_state              = false

  network_configuration = {
    subnets          = [for s in data.aws_subnets.vpc[0].ids : s]
    security_groups  = [var.cluster_security_group_id]
    assign_public_ip = false
  }

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.cwa_cfg.tags, null), {}))
}

module "fluent_bit_service" {
  source = "../service"
  count  = local.addon_enabled.fluent_bit ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-fluent-bit"

  container_definitions = [local.fluentbit_container]

  task_cpu    = try(local.fb_cfg.task_cpu, 256)
  task_memory = try(local.fb_cfg.task_memory, 256)

  network_mode             = "awsvpc"
  requires_compatibilities = local.addon_default_compat

  task_role_arn              = local.fb_task_role_arn
  execution_role_arn         = local.fb_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = coalesce(try(local.fb_cfg.volumes, null), [])

  desired_count              = 1
  launch_type                = local.addon_default_launch
  capacity_provider_strategy = []

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  wait_for_steady_state              = false

  network_configuration = {
    subnets          = [for s in data.aws_subnets.vpc[0].ids : s]
    security_groups  = [var.cluster_security_group_id]
    assign_public_ip = false
  }

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.fb_cfg.tags, null), {}))
}

# EC2 daemon-style agents: one task per node, bridge networking, host ports.
module "node_exporter_service" {
  source = "../service"
  count  = local.addon_enabled.node_exporter ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-node-exporter"

  container_definitions = [local.ne_container]

  task_cpu    = try(local.ne_cfg.task_cpu, 128)
  task_memory = try(local.ne_cfg.task_memory, 128)

  network_mode             = "bridge"
  requires_compatibilities = local.addon_ec2_daemon_compat

  task_role_arn              = local.ne_task_role_arn
  execution_role_arn         = local.ne_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = local.host_mount_volumes

  desired_count              = null
  launch_type                = "EC2"
  capacity_provider_strategy = []
  scheduling_strategy        = "DAEMON"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  wait_for_steady_state              = false

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.ne_cfg.tags, null), {}))
}

module "cadvisor_service" {
  source = "../service"
  count  = local.addon_enabled.cadvisor ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-cadvisor"

  container_definitions = [local.cadvisor_container]

  task_cpu    = try(local.cadvisor_cfg.task_cpu, 128)
  task_memory = try(local.cadvisor_cfg.task_memory, 128)

  network_mode             = "bridge"
  requires_compatibilities = local.addon_ec2_daemon_compat

  task_role_arn              = local.cadvisor_task_role_arn
  execution_role_arn         = local.cadvisor_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = local.host_mount_volumes

  desired_count              = null
  launch_type                = "EC2"
  capacity_provider_strategy = []
  scheduling_strategy        = "DAEMON"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  wait_for_steady_state              = false

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.cadvisor_cfg.tags, null), {}))
}

module "falco_service" {
  source = "../service"
  count  = local.addon_enabled.falco ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-falco"

  container_definitions = [local.falco_container]

  task_cpu    = try(local.falco_cfg.task_cpu, 512)
  task_memory = try(local.falco_cfg.task_memory, 512)

  network_mode             = "bridge"
  requires_compatibilities = local.addon_ec2_daemon_compat

  task_role_arn              = local.falco_task_role_arn
  execution_role_arn         = local.falco_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = local.host_mount_volumes

  desired_count              = null
  launch_type                = "EC2"
  capacity_provider_strategy = []
  scheduling_strategy        = "DAEMON"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  wait_for_steady_state              = false

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.falco_cfg.tags, null), {}))
}

module "blackbox_exporter_service" {
  source = "../service"
  count  = local.addon_enabled.blackbox_exporter ? 1 : 0

  cluster_id   = var.cluster_id
  cluster_name = var.cluster_name
  name         = "${var.cluster_name}-addon-blackbox-exporter"

  container_definitions = [local.blackbox_container]

  task_cpu    = try(local.bb_cfg.task_cpu, 256)
  task_memory = try(local.bb_cfg.task_memory, 256)

  network_mode             = "awsvpc"
  requires_compatibilities = local.addon_default_compat

  task_role_arn              = local.bb_task_role_arn
  execution_role_arn         = local.bb_execution_role_arn
  default_execution_role_arn = var.default_execution_role_arn
  infrastructure_role_arn    = var.infrastructure_role_arn
  volumes                    = coalesce(try(local.bb_cfg.volumes, null), [])

  desired_count              = 1
  launch_type                = local.addon_default_launch
  capacity_provider_strategy = []

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_execute_command             = true
  wait_for_steady_state              = false

  network_configuration = {
    subnets          = [for s in data.aws_subnets.vpc[0].ids : s]
    security_groups  = [var.cluster_security_group_id]
    assign_public_ip = false
  }

  use_tagger     = var.use_tagger
  tagger_context = var.tagger_context
  tags           = merge(var.tags, coalesce(try(local.bb_cfg.tags, null), {}))
}
