locals {
  # Tag profile: this service's cluster and task family.
  container_service_profile = {
    container = {
      cluster     = var.cluster_name
      task_family = var.name
    }
  }

  # Only configure_at_launch EBS volumes need tag_specifications - EFS/host-path
  # volumes aren't created by ECS and carry no cost of their own.
  ebs_volumes = [for v in var.volumes : v if try(v.configure_at_launch, false) && try(v.ebs_volume_configuration, null) != null]

  # Only fields immutable outside Terraform are tagged (same rule as RDS/ASG):
  # size/iops are excluded since ModifyVolume changes them live, causing
  # perpetual plan diffs.
  ebs_block_storage_profiles = {
    for v in local.ebs_volumes : v.name => merge(
      { type = try(v.ebs_volume_configuration.volume_type, null) },
      { file_system_type = try(v.ebs_volume_configuration.file_system_type, null) },
    )
  }

  taggable = merge(
    {
      this = {
        name       = var.name
        service    = local.container_service_profile
        attributes = ["service"]
        created_at = null
        extra_tags = {}
      }
      task = {
        name       = "${var.name}-task"
        service    = local.container_service_profile
        attributes = ["service", "task"]
        created_at = null
        extra_tags = {}
      }
    },
    # One taggable entry per managed EBS volume so the volume itself carries
    # the same standardized cost tags as the rest of the stack.
    { for v in local.ebs_volumes : "ebs-${v.name}" => {
      name       = "${var.name}-${v.name}"
      service    = merge(local.container_service_profile, { block_storage = local.ebs_block_storage_profiles[v.name] })
      attributes = ["service", "ebs", v.name]
      created_at = null
      extra_tags = {}
    } },
  )

  service_container_ports = distinct(sort(concat([
    for c in var.container_definitions :
    [for pm in try(c.portMappings, []) : pm.containerPort]
  ]...)))

  service_port_ranges = [for p in local.service_container_ports : { from = p, to = p }]
  # coalesce() short-circuits: a literal auto_ingress_enabled from the caller
  # skips evaluating the unknown-unsafe `cluster_security_group_id != null`.
  auto_ingress_enabled = coalesce(var.auto_ingress_enabled, var.cluster_security_group_id != null) && length(local.service_port_ranges) > 0

  # launch_type and capacity_provider_strategy are mutually exclusive on
  # aws_ecs_service - a non-empty strategy always wins.
  use_capacity_provider_strategy = length(var.capacity_provider_strategy) > 0

  daemon = var.scheduling_strategy == "DAEMON"

  task_execution_role_created = try(var.task_execution_role.create, null) != null
  task_role_created           = try(var.task_role.create, null) != null

  # coalesce() errors when every candidate is null, so the first non-null
  # wins via compact(); an all-null result stays null.
  execution_role_arn_candidates = compact([
    var.execution_role_arn,
    local.task_execution_role_created ? try(module.task_execution_role[0].arn, null) : null,
    try(var.task_execution_role.arn, null),
    var.default_execution_role_arn,
  ])
  execution_role_arn = try(local.execution_role_arn_candidates[0], null)

  task_role_arn_candidates = compact([
    var.task_role_arn,
    local.task_role_created ? try(module.task_role[0].arn, null) : null,
    try(var.task_role.arn, null),
  ])
  task_role_arn = try(local.task_role_arn_candidates[0], null)

  managed_ebs = var.managed_ebs_volume == null ? null : merge(var.managed_ebs_volume, {
    role_arn = coalesce(var.managed_ebs_volume.role_arn, var.default_ecs_infrastructure_role_arn)
  })
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = var.network_mode
  requires_compatibilities = var.requires_compatibilities
  task_role_arn            = local.task_role_arn
  execution_role_arn       = local.execution_role_arn
  container_definitions    = jsonencode(var.container_definitions)
  pid_mode                 = var.pid_mode
  ipc_mode                 = var.ipc_mode
  enable_fault_injection   = var.enable_fault_injection

  dynamic "runtime_platform" {
    for_each = var.runtime_platform == null ? [] : [var.runtime_platform]
    content {
      cpu_architecture        = runtime_platform.value.cpu_architecture
      operating_system_family = runtime_platform.value.operating_system_family
    }
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_gib == null ? [] : [1]
    content {
      size_in_gib = var.ephemeral_storage_gib
    }
  }

  dynamic "proxy_configuration" {
    for_each = var.proxy_configuration == null ? [] : [var.proxy_configuration]
    content {
      type           = proxy_configuration.value.type
      container_name = proxy_configuration.value.container_name
      properties     = proxy_configuration.value.properties
    }
  }

  dynamic "volume" {
    for_each = var.volumes
    content {
      name                = volume.value.name
      host_path           = try(volume.value.host_path, null)
      configure_at_launch = try(volume.value.configure_at_launch, false)

      dynamic "efs_volume_configuration" {
        # try() only guards a missing key, not a present-but-null one (a
        # caller sharing one shape across efs/ebs volumes hits this).
        for_each = try(volume.value.efs_volume_configuration, null) != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = try(efs_volume_configuration.value.root_directory, null)
          transit_encryption      = try(efs_volume_configuration.value.transit_encryption, null)
          transit_encryption_port = try(efs_volume_configuration.value.transit_encryption_port, null)
        }
      }

      dynamic "docker_volume_configuration" {
        for_each = try(volume.value.docker_volume_configuration, null) != null ? [volume.value.docker_volume_configuration] : []
        content {
          autoprovision = try(docker_volume_configuration.value.autoprovision, null)
          driver        = try(docker_volume_configuration.value.driver, null)
          driver_opts   = try(docker_volume_configuration.value.driver_opts, null)
          labels        = try(docker_volume_configuration.value.labels, null)
          scope         = try(docker_volume_configuration.value.scope, null)
        }
      }

      dynamic "fsx_windows_file_server_volume_configuration" {
        for_each = try(volume.value.fsx_windows_file_server_volume_configuration, null) != null ? [volume.value.fsx_windows_file_server_volume_configuration] : []
        content {
          file_system_id = fsx_windows_file_server_volume_configuration.value.file_system_id
          root_directory = try(fsx_windows_file_server_volume_configuration.value.root_directory, null)

          dynamic "authorization_config" {
            for_each = try(fsx_windows_file_server_volume_configuration.value.authorization_config, null) == null ? [] : [1]
            content {
              credentials_parameter = fsx_windows_file_server_volume_configuration.value.authorization_config.credentials_parameter
              domain                = try(fsx_windows_file_server_volume_configuration.value.authorization_config.domain, null)
            }
          }
        }
      }

      dynamic "s3files_volume_configuration" {
        for_each = try(volume.value.s3files_volume_configuration, null) != null ? [volume.value.s3files_volume_configuration] : []
        content {
          access_point_arn        = try(s3files_volume_configuration.value.access_point_arn, null)
          file_system_arn         = try(s3files_volume_configuration.value.file_system_arn, null)
          root_directory          = try(s3files_volume_configuration.value.root_directory, null)
          transit_encryption_port = try(s3files_volume_configuration.value.transit_encryption_port, null)
        }
      }
    }
  }

  tags = local.tagger_tags["task"]
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  # coalesce: a REPLICA service with no explicit count keeps the historical
  # default of 1 (the provider's own default is 0).
  desired_count = local.daemon ? null : coalesce(var.desired_count, 1)

  # AWS rejects launch_type on daemon services outright.
  launch_type         = local.daemon || local.use_capacity_provider_strategy ? null : var.launch_type
  scheduling_strategy = var.scheduling_strategy
  propagate_tags      = var.propagate_tags

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  deployment_maximum_percent         = local.daemon ? 100 : var.deployment_maximum_percent
  deployment_minimum_healthy_percent = local.daemon ? 0 : var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  enable_execute_command             = var.enable_execute_command
  # Required for Cost Explorer/CUR allocation of runtime-created tasks and
  # EBS volumes that Terraform itself doesn't manage.
  enable_ecs_managed_tags = var.enable_ecs_managed_tags
  wait_for_steady_state   = var.wait_for_steady_state
  force_new_deployment    = var.force_new_deployment

  dynamic "deployment_circuit_breaker" {
    for_each = var.deployment_circuit_breaker == null ? [] : [var.deployment_circuit_breaker]
    content {
      enable   = deployment_circuit_breaker.value.enable
      rollback = deployment_circuit_breaker.value.rollback
    }
  }

  dynamic "deployment_controller" {
    for_each = var.deployment_controller_type == null ? [] : [var.deployment_controller_type]
    content {
      type = deployment_controller.value
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.service_connect == null ? [] : [var.service_connect]
    content {
      enabled   = service_connect_configuration.value.enabled
      namespace = service_connect_configuration.value.namespace

      dynamic "service" {
        for_each = service_connect_configuration.value.service
        content {
          discovery_name        = service.value.discovery_name
          port_name             = try(service.value.port_name, null)
          ingress_port_override = try(service.value.ingress_port_override, null)

          dynamic "client_alias" {
            for_each = service.value.client_alias
            content {
              dns_name = client_alias.value.dns_name
              port     = client_alias.value.port
            }
          }
        }
      }
    }
  }

  dynamic "volume_configuration" {
    for_each = local.managed_ebs == null ? [] : [local.managed_ebs]
    content {
      name = volume_configuration.value.volume_name

      managed_ebs_volume {
        role_arn                   = volume_configuration.value.role_arn
        encrypted                  = volume_configuration.value.encrypted
        volume_type                = try(volume_configuration.value.volume_type, null)
        size_in_gb                 = try(volume_configuration.value.size_in_gb, null)
        iops                       = try(volume_configuration.value.iops, null)
        throughput                 = try(volume_configuration.value.throughput, null)
        snapshot_id                = try(volume_configuration.value.snapshot_id, null)
        kms_key_id                 = try(volume_configuration.value.kms_key_id, null)
        file_system_type           = try(volume_configuration.value.file_system_type, null)
        volume_initialization_rate = try(volume_configuration.value.volume_initialization_rate, null)

        dynamic "tag_specifications" {
          for_each = try(volume_configuration.value.tag_specifications, [])
          content {
            resource_type  = tag_specifications.value.resource_type
            tags           = try(tag_specifications.value.tags, null)
            propagate_tags = try(tag_specifications.value.propagate_tags, null)
          }
        }
      }
    }
  }

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [var.network_configuration] : []
    content {
      subnets          = network_configuration.value.subnets
      security_groups  = network_configuration.value.security_groups
      assign_public_ip = network_configuration.value.assign_public_ip
    }
  }

  # AWS rejects load_balancer on daemon services outright.
  dynamic "load_balancer" {
    for_each = local.daemon ? [] : var.load_balancer
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registries
    content {
      registry_arn   = service_registries.value.registry_arn
      port           = service_registries.value.port
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = placement_constraints.value.expression
    }
  }

  dynamic "ordered_placement_strategy" {
    for_each = var.ordered_placement_strategy
    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }

  # EBS volume configuration - the infrastructure role ARN is required for ECS
  # to manage the volume lifecycle (create, attach, detach, delete). Without
  # this, orphaned volumes are left behind when tasks stop.
  dynamic "volume_configuration" {
    for_each = [for v in var.volumes : v if try(v.configure_at_launch, false)]
    content {
      name = volume_configuration.value.name

      dynamic "managed_ebs_volume" {
        for_each = try(volume_configuration.value.ebs_volume_configuration, null) != null ? [volume_configuration.value.ebs_volume_configuration] : []
        content {
          role_arn         = coalesce(try(managed_ebs_volume.value.role_arn, null), var.infrastructure_role_arn)
          size_in_gb       = try(managed_ebs_volume.value.size_in_gib, null)
          snapshot_id      = try(managed_ebs_volume.value.snapshot_id, null)
          encrypted        = try(managed_ebs_volume.value.encrypted, true)
          kms_key_id       = try(managed_ebs_volume.value.kms_key_id, null)
          iops             = try(managed_ebs_volume.value.iops, null)
          throughput       = try(managed_ebs_volume.value.throughput, null)
          file_system_type = try(managed_ebs_volume.value.file_system_type, null)
          volume_type      = try(managed_ebs_volume.value.volume_type, null)

          # Without this the ECS runtime creates the volume untagged, and it
          # shows up as "unallocated" in Cost Explorer / CUR.
          tag_specifications {
            resource_type = "volume"
            tags          = local.tagger_tags["ebs-${volume_configuration.value.name}"]
          }
        }
      }
    }
  }

  tags = local.tagger_tags["this"]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  count = local.task_execution_role_created || local.task_role_created ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

module "task_execution_role" {
  source = "../iam-role"
  count  = local.task_execution_role_created ? 1 : 0

  name                        = var.task_execution_role.create.name
  assume_role_policy_document = data.aws_iam_policy_document.ecs_tasks_assume[0].json
  permissions_boundary_arn    = var.task_execution_role.create.permission_boundary_arn
  managed_policy_arns = concat(
    ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"],
    var.task_execution_role.create.managed_policy_arns,
  )
  inline_policies = var.task_execution_role.create.inline_policies
  least_privilege = var.task_execution_role.create.least_privilege
  tags            = local.tagger_tags["this"]
}

module "task_role" {
  source = "../iam-role"
  count  = local.task_role_created ? 1 : 0

  name                        = var.task_role.create.name
  assume_role_policy_document = data.aws_iam_policy_document.ecs_tasks_assume[0].json
  permissions_boundary_arn    = var.task_role.create.permission_boundary_arn
  managed_policy_arns         = var.task_role.create.managed_policy_arns
  inline_policies             = var.task_role.create.inline_policies
  least_privilege             = var.task_role.create.least_privilege
  tags                        = local.tagger_tags["this"]
}

resource "aws_security_group_rule" "service_ingress" {
  for_each = local.auto_ingress_enabled ? { for i, r in local.service_port_ranges : i => r } : {}

  type                     = "ingress"
  from_port                = each.value.from
  to_port                  = each.value.to
  protocol                 = "tcp"
  description              = "${var.name}: container port ${each.value.from}"
  source_security_group_id = var.cluster_security_group_id
  security_group_id        = var.cluster_security_group_id
}
