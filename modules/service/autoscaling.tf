resource "aws_appautoscaling_target" "this" {
  count = var.autoscaling_enabled ? 1 : 0

  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.autoscaling_min_capacity
  max_capacity       = var.autoscaling_max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.autoscaling_enabled && var.cpu_target_tracking != null ? 1 : 0

  name               = "${var.name}-cpu-target-tracking"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_tracking
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count = var.autoscaling_enabled && var.memory_target_tracking != null ? 1 : 0

  name               = "${var.name}-memory-target-tracking"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_tracking
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "alb_request_count" {
  count = var.autoscaling_enabled && var.alb_target_tracking != null ? 1 : 0

  name               = "${var.name}-alb-request-count"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCount"
      resource_label         = var.alb_target_tracking.resource_label
    }
    target_value       = var.alb_target_tracking.target_value
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_policy" "custom_metric" {
  count = var.autoscaling_enabled && var.custom_metric_target_tracking != null ? 1 : 0

  name               = "${var.name}-custom-metric"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = var.custom_metric_target_tracking.metric_name
      namespace   = var.custom_metric_target_tracking.namespace
      statistic   = var.custom_metric_target_tracking.statistic
      unit        = var.custom_metric_target_tracking.unit

      dynamic "dimensions" {
        for_each = var.custom_metric_target_tracking.dimensions
        content {
          name  = dimensions.value.name
          value = dimensions.value.value
        }
      }
    }
    target_value       = var.custom_metric_target_tracking.target_value
    scale_in_cooldown  = var.scale_in_cooldown_seconds
    scale_out_cooldown = var.scale_out_cooldown_seconds
  }
}

resource "aws_appautoscaling_scheduled_action" "this" {
  for_each = var.autoscaling_enabled ? { for a in var.scheduled_actions : a.name => a } : {}

  name               = each.key
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  schedule           = each.value.schedule
  timezone           = each.value.timezone

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
  }
}
