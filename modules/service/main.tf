locals {
  taggable = {
    this = {
      name       = var.name
      service    = {}
      attributes = []
      created_at = null
      extra_tags = {}
    }
  }

  execution_role_arn = coalesce(var.execution_role_arn, var.default_execution_role_arn)

  # launch_type and capacity_provider_strategy are mutually exclusive on
  # aws_ecs_service - a non-empty strategy always wins.
  use_capacity_provider_strategy = length(var.capacity_provider_strategy) > 0
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = var.network_mode
  requires_compatibilities = var.requires_compatibilities
  task_role_arn            = var.task_role_arn
  execution_role_arn       = local.execution_role_arn
  container_definitions = jsonencode(var.container_definitions)

  dynamic "volume" {
    for_each = var.volumes
    content {
      name                = volume.value.name
      host_path           = try(volume.value.host_path, null)
      configure_at_launch = try(volume.value.configure_at_launch, false)

      dynamic "efs_volume_configuration" {
        for_each = try([volume.value.efs_volume_configuration], [])
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = try(efs_volume_configuration.value.root_directory, null)
          transit_encryption      = try(efs_volume_configuration.value.transit_encryption, null)
          transit_encryption_port = try(efs_volume_configuration.value.transit_encryption_port, null)
        }
      }


    }
  }

  tags = local.tagger_tags["this"]
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  launch_type         = local.use_capacity_provider_strategy ? null : var.launch_type
  scheduling_strategy = var.scheduling_strategy

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  enable_execute_command             = var.enable_execute_command
  wait_for_steady_state              = var.wait_for_steady_state
  force_new_deployment               = var.force_new_deployment

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [var.network_configuration] : []
    content {
      subnets          = network_configuration.value.subnets
      security_groups  = network_configuration.value.security_groups
      assign_public_ip = network_configuration.value.assign_public_ip
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer
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
        for_each = try([volume_configuration.value.ebs_volume_configuration], [])
        content {
          role_arn           = coalesce(try(managed_ebs_volume.value.role_arn, null), var.infrastructure_role_arn)
          size_in_gb         = try(managed_ebs_volume.value.size_in_gib, null)
          snapshot_id        = try(managed_ebs_volume.value.snapshot_id, null)
          encrypted          = try(managed_ebs_volume.value.encrypted, true)
          kms_key_id         = try(managed_ebs_volume.value.kms_key_id, null)
          iops               = try(managed_ebs_volume.value.iops, null)
          throughput         = try(managed_ebs_volume.value.throughput, null)
          file_system_type   = try(managed_ebs_volume.value.file_system_type, null)
          volume_type        = try(managed_ebs_volume.value.volume_type, null)
        }
      }
    }
  }

  tags = local.tagger_tags["this"]

  lifecycle {
    ignore_changes = [desired_count]
  }
}
