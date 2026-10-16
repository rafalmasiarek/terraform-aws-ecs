locals {
  # ECS platform context for the standardized tag set: every cluster-level
  # resource is tagged with the container profile ({ cluster }) so cost and
  # ownership tooling can group by cluster.
  cluster_service_profile = {
    container = {
      cluster = var.name
    }
  }

  taggable = {
    this = {
      name       = var.name
      service    = local.cluster_service_profile
      attributes = ["cluster"]
      created_at = null
      extra_tags = {}
    }
  }

  cloudwatch_log_group_name = "/aws/ecs/${var.name}"
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  dynamic "configuration" {
    for_each = var.create_cloudwatch_log_group ? [1] : []
    content {
      execute_command_configuration {
        logging = "OVERRIDE"
        log_configuration {
          cloud_watch_log_group_name = aws_cloudwatch_log_group.this[0].name
        }
      }
    }
  }

  tags = local.tagger_tags["this"]
}

resource "aws_cloudwatch_log_group" "this" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  name              = local.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_log_group_retention_in_days

  tags = local.tagger_tags["this"]
}

resource "aws_ecs_capacity_provider" "ec2" {
  for_each = var.node_groups

  name = "${var.name}-${each.key}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = module.node_group[each.key].autoscaling_group_arn
    managed_termination_protection = try(each.value.managed_termination_protection, "ENABLED")
    managed_draining               = try(each.value.managed_draining, "ENABLED")

    managed_scaling {
      status                    = try(each.value.managed_scaling.status, "ENABLED")
      target_capacity           = try(each.value.managed_scaling.target_capacity, 100)
      minimum_scaling_step_size = try(each.value.managed_scaling.minimum_scaling_step_size, 1)
      maximum_scaling_step_size = try(each.value.managed_scaling.maximum_scaling_step_size, 1)
      instance_warmup_period    = try(each.value.managed_scaling.instance_warmup_period, 300)
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = concat(
    [for cp in aws_ecs_capacity_provider.ec2 : cp.name],
    var.fargate_capacity_providers,
  )
}
