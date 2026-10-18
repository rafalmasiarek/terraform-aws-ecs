output "autoscaling_group_arn" {
  value = module.nodes.autoscaling_group_arn
}

output "autoscaling_group_name" {
  value = module.nodes.autoscaling_group_name
}

output "instance_profile_name" {
  value = local.node_role_profile_name
}

output "agent_config_script" {
  value = local.agent_config_script
}

output "agent_start_unit" {
  value = local.agent_start_unit
}
