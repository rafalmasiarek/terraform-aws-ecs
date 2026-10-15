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
  for_each = toset(var.managed_policy_arns)

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
  count = module.least_privilege.json != "" ? 1 : 0

  name   = "least-privilege"
  role   = aws_iam_role.this.id
  policy = module.least_privilege.json
}
