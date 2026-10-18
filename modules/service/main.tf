locals {
  # ECS platform context for the standardized tag set: the cluster the
  # service runs in and its task family (the task definition's family).
  container_service_profile = {
    container = {
      cluster     = var.cluster_name
      task_family = var.name
    }
  }

  # EBS volumes that ECS manages at launch (configure_at_launch). These are
  # the only volumes that need tag_specifications - EFS/host-path volumes are
  # not created by ECS and carry no cost of their own.
  ebs_volumes = [for v in var.volumes : v if try(v.configure_at_launch, false) && try(v.ebs_volume_configuration, null) != null]

  # block_storage profile per managed volume. Only fields that CANNOT change
  # outside Terraform are tagged - the same rule the tagger applies to RDS
  # (storage_gb excluded: storage autoscaling) and ASG (desired_capacity
  # excluded: autoscaler). EBS size and iops CAN be changed live via
  # ModifyVolume (resize, gp3 performance tuning), so they're deliberately
  # left out to avoid perpetual plan diffs / false positives. What remains is
  # genuinely stable: the volume type family and the filesystem on top.
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

  execution_role_arn = coalesce(var.execution_role_arn, var.default_execution_role_arn)

  # launch_type and capacity_provider_strategy are mutually exclusive on
  # aws_ecs_service - a non-empty strategy always wins.
  use_capacity_provider_strategy = length(var.capacity_provider_strategy) > 0

  service_container_ports = distinct(sort(concat([
    for c in var.container_definitions :
    [for pm in try(c.portMappings, []) : pm.containerPort]
  ]...)))

  service_port_ranges = [for p in local.service_container_ports : { from = p, to = p }]
  # coalesce() short-circuits on the first non-null argument without
  # needing the second to be known - callers that pass a literal
  # auto_ingress_enabled avoid ever evaluating the unknown-unsafe
  # `cluster_security_group_id != null` check (see that variable's
  # description).
  auto_ingress_enabled = coalesce(var.auto_ingress_enabled, var.cluster_security_group_id != null) && length(local.service_port_ranges) > 0
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = var.network_mode
  requires_compatibilities = var.requires_compatibilities
  task_role_arn            = var.task_role_arn
  execution_role_arn       = local.execution_role_arn
  container_definitions    = jsonencode(var.container_definitions)

  dynamic "volume" {
    for_each = var.volumes
    content {
      name                = volume.value.name
      host_path           = try(volume.value.host_path, null)
      configure_at_launch = try(volume.value.configure_at_launch, false)

      dynamic "efs_volume_configuration" {
        # try() only guards a missing attribute - an object with the key
        # present but null (common when a caller builds one shared shape
        # for both efs/ebs volumes) would otherwise run this block against
        # a null value.
        for_each = try(volume.value.efs_volume_configuration, null) != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = try(efs_volume_configuration.value.root_directory, null)
          transit_encryption      = try(efs_volume_configuration.value.transit_encryption, null)
          transit_encryption_port = try(efs_volume_configuration.value.transit_encryption_port, null)
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
  # ECS-managed tags: when enabled, ECS automatically tags every launched task
  # and every EBS volume it attaches with aws:ecs:clusterName /
  # aws:ecs:serviceName plus the user-added task-definition/service tags. This
  # is what makes cost allocation work in Cost Explorer / CUR for the runtime-
  # created volumes and tasks that Terraform doesn't manage directly.
  enable_ecs_managed_tags = var.enable_ecs_managed_tags
  wait_for_steady_state   = var.wait_for_steady_state
  force_new_deployment    = var.force_new_deployment

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

          # Tag the ECS-managed volume directly so it carries the same
          # standardized cost tags as the rest of the stack (including the
          # block_storage profile: size/type/iops/file_system_type). Without
          # this the volume is created untagged by the ECS runtime and shows
          # up as "unallocated" in Cost Explorer / CUR.
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
