# Observability addon: cluster-level CloudWatch dashboards and alarms.
# Creates management resources that observe the other addons and root services.
# This is NOT a service — no task definition, no ECS service.

locals {
  obs_cfg     = try(var.cluster_addons.observability, {})
  obs_enabled = local.addon_enabled.observability

  # Discover which metric-exporting addons are active.
  obs_has_traefik = local.addon_enabled.traefik
}

# ---------------------------------------------------------------------------
# CloudWatch Dashboard
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "this" {
  count = local.obs_enabled && try(local.obs_cfg.cloudwatch_dashboard, true) ? 1 : 0

  dashboard_name = "${var.cluster_name}-addons"

  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "metric",
          x      = 0, y = 0, width = 12, height = 6
          properties = {
            metrics = [
              ["AWS/ECS", "ServiceTasksRunning", "ClusterName", var.cluster_name, "Statistic", "Sum", "Period", "300"],
            ]
            title  = "ECS Service Tasks Running"
            region = data.aws_region.current.region
            stat   = "Sum"
            period = 300
            view   = "timeSeries"
          }
        },
        {
          type   = "metric",
          x      = 12, y = 0, width = 12, height = 6
          properties = {
            metrics = [
              ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${var.cluster_name}-*", "Statistic", "Average", "Period", "300"],
            ]
            title  = "Node CPU Utilization (%)"
            region = data.aws_region.current.region
            stat   = "Average"
            period = 300
            view   = "timeSeries"
          }
        },
        {
          type   = "metric",
          x      = 0, y = 6, width = 12, height = 6
          properties = {
            metrics = [
              ["AWS/EC2", "MemoryUtilization", "AutoScalingGroupName", "${var.cluster_name}-*", "Statistic", "Average", "Period", "300"],
            ]
            title  = "Node Memory Utilization (%)"
            region = data.aws_region.current.region
            stat   = "Average"
            period = 300
            view   = "timeSeries"
          }
        },
      ],
      local.obs_has_traefik ? [
        {
          type   = "metric",
          x      = 12, y = 6, width = 12, height = 6
          properties = {
            metrics = [
              ["AWS/ApplicationLoadBalancer", "RequestCount", "LoadBalancer", "app/${var.cluster_name}-addon-traefik*", "Statistic", "Sum", "Period", "300"],
              ["AWS/ApplicationLoadBalancer", "HTTPCode_Target_5XX_Count", "LoadBalancer", "app/${var.cluster_name}-addon-traefik*", "Statistic", "Sum", "Period", "300"],
            ]
            title  = "Traefik LB: Requests & 5xx"
            region = data.aws_region.current.region
            view   = "timeSeries"
          }
        },
      ] : [],
    )
  })
}

# ---------------------------------------------------------------------------
# CloudWatch Alarms
# ---------------------------------------------------------------------------

# Alarm per addon service: running task count drops below threshold.
resource "aws_cloudwatch_metric_alarm" "service_tasks_zero" {
  for_each = local.obs_enabled && try(local.obs_cfg.alarms, true) ? local.addon_services : {}

  alarm_name          = "${var.cluster_name}-addon-${each.key}-tasks-zero"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Sum"
  threshold           = 1

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = "${var.cluster_name}-addon-${each.key}"
  }

  alarm_description = "Addon ${each.key} has fewer than 1 running task for 10 minutes."
}

# Alarm: Node CPU sustained above threshold.
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  count = local.obs_enabled && try(local.obs_cfg.alarms, true) ? 1 : 0

  alarm_name          = "${var.cluster_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = try(local.obs_cfg.cpu_alarm_threshold, 80)

  dimensions = {
    AutoScalingGroupName = "${var.cluster_name}-*"
  }

  alarm_description = "Any node sustained >${try(local.obs_cfg.cpu_alarm_threshold, 80)}% CPU for 15 minutes."
}

# Alarm: Node memory sustained above threshold.
resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  count = local.obs_enabled && try(local.obs_cfg.alarms, true) ? 1 : 0

  alarm_name          = "${var.cluster_name}-node-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = try(local.obs_cfg.memory_alarm_threshold, 90)

  dimensions = {
    AutoScalingGroupName = "${var.cluster_name}-*"
  }

  alarm_description = "Any node sustained >${try(local.obs_cfg.memory_alarm_threshold, 90)}% memory for 15 minutes."
}
