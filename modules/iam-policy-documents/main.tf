locals {
  least_privilege_arns = concat(
    var.least_privilege.ecr_registry_arns,
    var.least_privilege.secretsmanager_secret_arns,
    var.least_privilege.ssm_parameter_arns,
    var.least_privilege.kms_key_arns,
    var.least_privilege.route53_hosted_zone_arns,
  )
}

data "aws_iam_policy_document" "this" {
  count = length(local.least_privilege_arns) > 0 ? 1 : 0

  # ecr:GetAuthorizationToken only accepts Resource "*", so the token and the
  # repository-scoped pull actions (incl. layer downloads) need separate
  # statements.
  dynamic "statement" {
    for_each = length(var.least_privilege.ecr_registry_arns) > 0 ? [1] : []
    content {
      sid       = "EcrPullToken"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.least_privilege.ecr_registry_arns) > 0 ? [1] : []
    content {
      sid       = "EcrPull"
      effect    = "Allow"
      actions   = ["ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer"]
      resources = var.least_privilege.ecr_registry_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.least_privilege.secretsmanager_secret_arns) > 0 ? [1] : []
    content {
      sid       = "SecretsManagerGet"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.least_privilege.secretsmanager_secret_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.least_privilege.ssm_parameter_arns) > 0 ? [1] : []
    content {
      sid    = "SsmGetParameter"
      effect = "Allow"
      # Container secrets are read with the batch action (ssm:GetParameters),
      # not ssm:GetParameter - both are needed.
      actions   = ["ssm:GetParameter", "ssm:GetParameters"]
      resources = var.least_privilege.ssm_parameter_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.least_privilege.kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "KmsDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.least_privilege.kms_key_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.least_privilege.route53_hosted_zone_arns) > 0 ? [1] : []
    content {
      sid       = "Route53Records"
      effect    = "Allow"
      actions   = ["route53:GetHostedZone", "route53:ChangeResourceRecordSets"]
      resources = var.least_privilege.route53_hosted_zone_arns
    }
  }
}
