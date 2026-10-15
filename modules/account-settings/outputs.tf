output "setting_names" {
  value = sort(keys(var.settings))
}
