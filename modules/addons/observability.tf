# Observability addon: cluster-level CloudWatch dashboards and alarms.
# Creates management resources that observe the other addons and root services.
# This is NOT a service — no task definition, no ECS service.
#
# NOTE: obs_* locals live in main.tf (not here). They must stay out of this
# file's dependency graph: local.taggable references them, and if they were
# defined alongside the resources they gate (which consume local.tagger_tags
# from module.tagger), Terraform would see a cycle through the SNS topic ARN.

locals {
  obs_cfg         = try(var.cluster_addons.observability, {})
  obs_enabled     = local.addon_enabled.observability
  obs_has_traefik = local.addon_enabled.traefik

  # SNS topic resolution:
  # 1. User provides existing sns_topic_arn -> use it
  # 2. create_sns_topic = true -> module creates one
  # 3. Neither -> no alarm_actions (alarms exist but notify nowhere)
  # obs_create_sns and obs_custom_sns_topics live in main.tf (shared with
  # local.taggable); only the ARN-dependent locals are defined here.
  obs_sns_topic_arn = coalesce(
    try(local.obs_cfg.sns_topic_arn, null),
    local.obs_create_sns ? aws_sns_topic.this[0].arn : null,
  )

  # Alarm actions: list of SNS topic ARNs to notify on ALARM state.
  obs_alarm_actions = local.obs_sns_topic_arn != null ? [local.obs_sns_topic_arn] : []

  # obs_custom_sns_topics lives in main.tf (shared with local.taggable).
  obs_all_alarm_actions = concat(local.obs_alarm_actions, local.obs_custom_sns_topics)
}

# ---------------------------------------------------------------------------
# SNS Topic (optional, created by the module)
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "this" {
  count = local.obs_enabled && local.obs_create_sns ? 1 : 0

  name = coalesce(try(local.obs_cfg.sns_topic_name, null), "${var.cluster_name}-addons-alerts")

  # No resource policy: access is controlled via IAM (CloudWatch, EventBridge).
  # The topic is NOT publicly accessible.

  tags = local.tagger_tags["obs-sns"]
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
          type = "metric",
          x    = 0, y = 0, width = 12, height = 6
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
          type = "metric",
          x    = 12, y = 0, width = 12, height = 6
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
          type = "metric",
          x    = 0, y = 6, width = 12, height = 6
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
          type = "metric",
          x    = 12, y = 6, width = 12, height = 6
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
  alarm_actions     = local.obs_all_alarm_actions

  tags = local.tagger_tags["obs-alarm-${each.key}"]
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
  alarm_actions     = local.obs_all_alarm_actions

  tags = local.tagger_tags["obs-alarm-node-cpu"]
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
  alarm_actions     = local.obs_all_alarm_actions

  tags = local.tagger_tags["obs-alarm-node-mem"]
}

# ---------------------------------------------------------------------------
# CloudWatch Event Rules: ASG scaling + ECS deployment events -> SNS
# ---------------------------------------------------------------------------

# ASG lifecycle events (scale up/down, instance launch/terminate).
resource "aws_cloudwatch_event_rule" "asg_scaling" {
  count = length(local.obs_all_alarm_actions) > 0 ? 1 : 0

  name        = "${var.cluster_name}-addons-asg-scaling"
  description = "ASG scaling events for ${var.cluster_name} node groups"
  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail_type = ["EC2 Auto Scaling group scaling activity", "EC2 Auto Scaling group lifecycle action"]
    detail = {
      AutoScalingGroupName = ["${var.cluster_name}-*"]
    }
  })

  tags = local.tagger_tags["obs-event-asg"]
}

resource "aws_cloudwatch_event_target" "asg_scaling_sns" {
  count = length(local.obs_all_alarm_actions) > 0 ? 1 : 0

  rule = aws_cloudwatch_event_rule.asg_scaling[0].name
  arn  = local.obs_all_alarm_actions[0]
}

# ECS service deployment events (DEPLOYMENT_STARTED, DEPLOYMENT_SUCCEEDED, DEPLOYMENT_FAILED).
resource "aws_cloudwatch_event_rule" "ecs_deployments" {
  count = length(local.obs_all_alarm_actions) > 0 ? 1 : 0

  name        = "${var.cluster_name}-addons-ecs-deployments"
  description = "ECS deployment events for ${var.cluster_name}"
  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail_type = ["ECS Deployment"]
    detail = {
      clusterArn = [var.cluster_id]
    }
  })

  tags = local.tagger_tags["obs-event-ecs"]
}

resource "aws_cloudwatch_event_target" "ecs_deployments_sns" {
  count = length(local.obs_all_alarm_actions) > 0 ? 1 : 0

  rule = aws_cloudwatch_event_rule.ecs_deployments[0].name
  arn  = local.obs_all_alarm_actions[0]
}
