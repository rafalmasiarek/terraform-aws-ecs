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

  cloudwatch_log_group_name = "/aws/ecs/${var.name}"

  exec_s3_bucket_create = try(var.exec_command_s3.bucket.create, false) == true
  exec_s3_bucket_name = var.exec_command_s3 == null ? null : (
    try(var.exec_command_s3.bucket.name, null) != null
    ? var.exec_command_s3.bucket.name
    : "${var.name}-exec-logs-${try(data.aws_region.current[0].region, var.name)}"
  )
  exec_s3_key_prefix = var.exec_command_s3 == null ? null : coalesce(var.exec_command_s3.bucket.key_prefix, var.name)
  exec_kms_create    = try(var.exec_command_s3.kms.create, false) == true
  exec_kms_key_id    = local.exec_kms_create ? try(aws_kms_key.exec[0].id, null) : try(var.exec_command_s3.kms.key_id, null)

  # An explicitly supplied existing log group also enables exec logging -
  # otherwise the destination is returned in outputs but never configured.
  exec_logging_enabled = var.create_cloudwatch_log_group || var.cloudwatch_log_group_name != null || var.exec_command_s3 != null
  exec_cwl_name        = var.create_cloudwatch_log_group ? try(aws_cloudwatch_log_group.this[0].name, null) : coalesce(var.cloudwatch_log_group_name, local.cloudwatch_log_group_name)

  exec_s3_bucket_arn = local.exec_s3_bucket_name == null ? null : (
    local.exec_s3_bucket_create ? try(aws_s3_bucket.exec[0].arn, null) : "arn:aws:s3:::${local.exec_s3_bucket_name}"
  )
}

data "aws_region" "current" {
  count = local.exec_s3_bucket_create && try(var.exec_command_s3.bucket.name, null) == null ? 1 : 0
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  dynamic "setting" {
    for_each = var.container_insights == null ? [] : [var.container_insights]
    content {
      name  = "containerInsights"
      value = setting.value
    }
  }

  dynamic "configuration" {
    for_each = local.exec_logging_enabled ? [1] : []
    content {
      execute_command_configuration {
        logging    = "OVERRIDE"
        kms_key_id = local.exec_kms_key_id
        log_configuration {
          cloud_watch_log_group_name     = local.exec_cwl_name
          cloud_watch_encryption_enabled = local.exec_cwl_name != null && var.cloudwatch_log_group_kms_key_id != null ? true : null
          s3_bucket_name                 = local.exec_s3_bucket_name
          s3_key_prefix                  = local.exec_s3_key_prefix
          s3_bucket_encryption_enabled   = local.exec_kms_key_id != null && local.exec_s3_bucket_name != null ? true : null
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
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = local.tagger_tags["this"]
}

data "aws_caller_identity" "current" {
  count = local.exec_kms_create ? 1 : 0
}

data "aws_iam_policy_document" "exec_kms" {
  count = local.exec_kms_create ? 1 : 0

  # KMS rejects key policies that would not let the account update the policy
  # in the future - account root keeps full key admin.
  statement {
    sid       = "AccountAdmin"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current[0].account_id}:root"]
    }
  }

  statement {
    sid       = "ECSCluster"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "S3"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3:::${local.exec_s3_bucket_name}"]
    }
  }
}

resource "aws_kms_key" "exec" {
  count = local.exec_kms_create ? 1 : 0

  description         = "ECS Exec S3 logging key for cluster ${var.name}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.exec_kms[0].json

  tags = local.tagger_tags["this"]
}

resource "aws_s3_bucket" "exec" {
  count = local.exec_s3_bucket_create ? 1 : 0

  bucket = local.exec_s3_bucket_name

  tags = local.tagger_tags["this"]
}

resource "aws_s3_bucket_public_access_block" "exec" {
  count = local.exec_s3_bucket_create ? 1 : 0

  bucket                  = aws_s3_bucket.exec[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "exec" {
  count = local.exec_s3_bucket_create ? 1 : 0

  bucket = aws_s3_bucket.exec[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.exec_kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = local.exec_kms_key_id
    }
  }
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

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}
