output "json" {
  value = try(data.aws_iam_policy_document.this[0].json, "")
}
