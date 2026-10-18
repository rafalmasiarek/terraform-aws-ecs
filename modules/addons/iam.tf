# Per-preset IAM. Each enabled preset gets its own task role and execution
# role so policies stay scoped to what that one agent needs; extra_task_policies
# on a preset extends it without touching the others.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "addon_assume_role" {
  count = length(local.addon_services) > 0 ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

locals {
  # Every execution role gets the ECS task execution policy (pull images,
  # write CloudWatch Logs) - awslogs tasks fail placement without it.
  addon_base_execution_policies = { for k in local.addon_all_keys : k => ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"] }

  # Base task policies (the minimum the agent itself needs beyond logging).
  # Only presets that call an AWS API from inside the container need one -
  # node_exporter/cadvisor/falco/blackbox_exporter only expose metrics over
  # HTTP or scan the local host, no AWS API calls.
  addon_base_task_policies = {
    traefik           = []
    opentelemetry     = []
    cloudwatch_agent  = []
    fluent_bit        = []
    node_exporter     = []
    cadvisor          = []
    falco             = []
    blackbox_exporter = []
  }

  # Base inline statements, merged with extra_task_policies.inline_policies
  # below. List/describe-only actions (no resource-level permissions in
  # IAM) stay Resource="*"; log-group-scoped actions are scoped to this
  # preset's own addon log group.
  addon_base_task_inline_policies = {
    traefik = {
      ecs-discovery = [{
        effect    = "Allow"
        actions   = ["ecs:ListClusters", "ecs:ListTasks", "ecs:DescribeTasks", "ecs:DescribeTaskDefinition", "ecs:DescribeContainerInstances", "ec2:DescribeInstances"]
        resources = ["*"]
      }]
    }
    cloudwatch_agent = {
      metrics = [{
        effect    = "Allow"
        actions   = ["cloudwatch:PutMetricData"]
        resources = ["*"]
      }]
    }
    fluent_bit = {
      logs = [{
        effect    = "Allow"
        actions   = ["logs:PutLogEvents", "logs:CreateLogStream", "logs:DescribeLogStreams"]
        resources = ["arn:aws:logs:*:*:log-group:/aws/ecs/${var.cluster_name}/addons/*:*"]
      }]
    }
    opentelemetry = {
      export = [{
        effect    = "Allow"
        actions   = ["cloudwatch:PutMetricData", "xray:PutTraceSegments", "xray:PutTelemetryRecords", "logs:PutLogEvents", "logs:CreateLogStream", "logs:DescribeLogStreams"]
        resources = ["*"]
      }]
    }
    node_exporter     = {}
    cadvisor          = {}
    falco             = {}
    blackbox_exporter = {}
  }

  addon_extra_task_policies = { for k in keys(local.addon_services) : k => try(var.cluster_addons[k].extra_task_policies, {}) }
}

resource "aws_iam_role" "task" {
  for_each = local.addon_services

  name               = "${var.cluster_name}-addon-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.addon_assume_role[0].json

  tags = local.tagger_tags["${each.key}-task"]
}

resource "aws_iam_role" "execution" {
  for_each = local.addon_services

  name               = "${var.cluster_name}-addon-${each.key}-execution"
  assume_role_policy = data.aws_iam_policy_document.addon_assume_role[0].json

  tags = local.tagger_tags["${each.key}-execution"]
}

# Managed policy attachments: base + caller extras (task and execution roles).
resource "aws_iam_role_policy_attachment" "task_managed" {
  for_each = {
    for pair in flatten([
      for k in keys(local.addon_services) : [
        for arn in concat(
          coalesce(try(local.addon_base_task_policies[k], null), []),
          coalesce(try(local.addon_extra_task_policies[k].managed_policy_arns, null), []),
        ) : { key = "${k}:task:${arn}", arn = arn, service_key = k, role = "task" }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.task[each.value.service_key].name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  for_each = {
    for pair in flatten([
      for k in keys(local.addon_services) : [
        for arn in concat(
          coalesce(try(local.addon_base_execution_policies[k], null), []),
          [],
        ) : { key = "${k}:exec:${arn}", arn = arn, service_key = k, role = "execution" }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.execution[each.value.service_key].name
  policy_arn = each.value.arn
}

# Inline policies: this preset's base statements + extra_task_policies.inline_policies.
resource "aws_iam_role_policy" "task_inline" {
  for_each = {
    for pair in flatten([
      for k in keys(local.addon_services) : [
        for sid, stmts in merge(
          coalesce(try(local.addon_base_task_inline_policies[k], null), {}),
          coalesce(try(local.addon_extra_task_policies[k].inline_policies, null), {}),
          ) : [
          for s in stmts : { key = "${k}:${sid}", service_key = k, sid = sid, effect = s.effect, actions = s.actions, resources = s.resources }
        ]
      ]
    ]) : pair.key => pair
  }

  # sid must be part of the name - two sids on the same role previously
  # collided on an identical name, so the second PutRolePolicy silently
  # overwrote the first.
  name = "${var.cluster_name}-addon-${each.value.service_key}-inline-${each.value.sid}"
  role = aws_iam_role.task[each.value.service_key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = each.value.sid
      Effect   = each.value.effect
      Action   = each.value.actions
      Resource = each.value.resources
    }]
  })
}

# The managed AmazonECSTaskExecutionRolePolicy does not grant
# logs:CreateLogGroup / logs:DescribeLogGroups / logs:DescribeLogStreams in
# every region (verified missing in eu-central-1), which makes the agent's
# awslogs validation fail at task start ("cannot find the log group"). Grant
# the full awslogs set scoped to this cluster's addon log groups.
resource "aws_iam_role_policy" "execution_awslogs" {
  for_each = local.addon_services

  name = "${var.cluster_name}-addon-${each.key}-awslogs"
  role = aws_iam_role.execution[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:PutLogEvents"]
      Resource = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/${var.cluster_name}*",
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/${var.cluster_name}*:log-stream:*",
      ]
    }]
  })
}

# Traefik ACME: DNS-01 challenge records are managed by traefik itself -
# the task role needs Route53 record mutation on the caller's zones.
resource "aws_iam_role_policy" "traefik_acme_dns" {
  count = local.addon_enabled.traefik && local.traefik_acme ? 1 : 0

  name = "${var.cluster_name}-addon-traefik-acme-dns"
  role = aws_iam_role.task["traefik"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListZones"
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones"]
        Resource = ["*"]
      },
      {
        Sid      = "ChangeRecords"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Sid      = "PollChange"
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = ["arn:aws:route53:::change/*"]
      },
    ]
  })
}

locals {
  traefik_task_role_arn       = local.addon_enabled.traefik ? aws_iam_role.task["traefik"].arn : null
  traefik_execution_role_arn  = local.addon_enabled.traefik ? aws_iam_role.execution["traefik"].arn : null
  otel_task_role_arn          = local.addon_enabled.opentelemetry ? aws_iam_role.task["opentelemetry"].arn : null
  otel_execution_role_arn     = local.addon_enabled.opentelemetry ? aws_iam_role.execution["opentelemetry"].arn : null
  cwa_task_role_arn           = local.addon_enabled.cloudwatch_agent ? aws_iam_role.task["cloudwatch_agent"].arn : null
  cwa_execution_role_arn      = local.addon_enabled.cloudwatch_agent ? aws_iam_role.execution["cloudwatch_agent"].arn : null
  fb_task_role_arn            = local.addon_enabled.fluent_bit ? aws_iam_role.task["fluent_bit"].arn : null
  fb_execution_role_arn       = local.addon_enabled.fluent_bit ? aws_iam_role.execution["fluent_bit"].arn : null
  ne_task_role_arn            = local.addon_enabled.node_exporter ? aws_iam_role.task["node_exporter"].arn : null
  ne_execution_role_arn       = local.addon_enabled.node_exporter ? aws_iam_role.execution["node_exporter"].arn : null
  cadvisor_task_role_arn      = local.addon_enabled.cadvisor ? aws_iam_role.task["cadvisor"].arn : null
  cadvisor_execution_role_arn = local.addon_enabled.cadvisor ? aws_iam_role.execution["cadvisor"].arn : null
  falco_task_role_arn         = local.addon_enabled.falco ? aws_iam_role.task["falco"].arn : null
  falco_execution_role_arn    = local.addon_enabled.falco ? aws_iam_role.execution["falco"].arn : null
  bb_task_role_arn            = local.addon_enabled.blackbox_exporter ? aws_iam_role.task["blackbox_exporter"].arn : null
  bb_execution_role_arn       = local.addon_enabled.blackbox_exporter ? aws_iam_role.execution["blackbox_exporter"].arn : null
}
