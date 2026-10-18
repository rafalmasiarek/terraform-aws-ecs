resource "aws_ecs_account_setting_default" "this" {
  for_each = var.settings

  name  = each.key
  value = each.value
}
