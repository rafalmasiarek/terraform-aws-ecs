locals {
  # Index keys (plan-known) so computed ARNs - e.g. an aws_iam_policy created
  # in the same apply - can be attached. IAM AttachRolePolicy is idempotent,
  # so a duplicated ARN degrades to a no-op instead of failing.
  managed_policy_attachments = { for i, arn in var.managed_policy_arns : i => arn }

  # Plan-known existence check: the rendered JSON is unknown while any scoped
  # ARN is computed, so the count must come from the input structure.
  least_privilege_present = length(concat(
    var.least_privilege.ecr_registry_arns,
    var.least_privilege.secretsmanager_secret_arns,
    var.least_privilege.ssm_parameter_arns,
    var.least_privilege.kms_key_arns,
    var.least_privilege.route53_hosted_zone_arns,
  )) > 0
}

module "least_privilege" {
  source = "../iam-policy-documents"

  least_privilege = var.least_privilege
}

resource "aws_iam_role" "this" {
  name                 = var.name
  assume_role_policy   = var.assume_role_policy_document
  permissions_boundary = var.permissions_boundary_arn

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.managed_policy_attachments

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "inline" {
  for_each = var.inline_policies

  dynamic "statement" {
    for_each = each.value
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline[each.key].json
}

resource "aws_iam_role_policy" "least_privilege" {
  count = local.least_privilege_present ? 1 : 0

  name   = "least-privilege"
  role   = aws_iam_role.this.id
  policy = module.least_privilege.json
}
