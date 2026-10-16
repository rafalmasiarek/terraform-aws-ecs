output "traefik" {
  description = "Traefik add-on outputs (null when the preset is disabled)."
  value = local.addon_enabled.traefik ? {
    service_name           = try(module.traefik_service[0].service_name, null)
    task_definition_arn    = try(module.traefik_service[0].task_definition_arn, null)
    load_balancer_id       = local.traefik_create_lb ? try(aws_lb.traefik[0].id, null) : null
    load_balancer_arn      = local.traefik_create_lb ? try(aws_lb.traefik[0].arn, null) : null
    load_balancer_dns_name = local.traefik_create_lb ? try(aws_lb.traefik[0].dns_name, null) : null
    target_group_arn_80    = local.traefik_tg_arn_80
    target_group_arn_443   = local.traefik_tg_arn_443
  } : null
}

output "opentelemetry" {
  description = "OpenTelemetry collector outputs (null when disabled)."
  value = local.addon_enabled.opentelemetry ? {
    service_name        = try(module.opentelemetry_service[0].service_name, null)
    task_definition_arn = try(module.opentelemetry_service[0].task_definition_arn, null)
  } : null
}

output "cloudwatch_agent" {
  description = "CloudWatch agent outputs (null when disabled)."
  value = local.addon_enabled.cloudwatch_agent ? {
    service_name        = try(module.cloudwatch_agent_service[0].service_name, null)
    task_definition_arn = try(module.cloudwatch_agent_service[0].task_definition_arn, null)
  } : null
}

output "fluent_bit" {
  description = "Fluent Bit outputs (null when disabled)."
  value = local.addon_enabled.fluent_bit ? {
    service_name        = try(module.fluent_bit_service[0].service_name, null)
    task_definition_arn = try(module.fluent_bit_service[0].task_definition_arn, null)
  } : null
}

output "node_exporter" {
  description = "Node exporter outputs (null when disabled)."
  value = local.addon_enabled.node_exporter ? {
    service_name        = try(module.node_exporter_service[0].service_name, null)
    task_definition_arn = try(module.node_exporter_service[0].task_definition_arn, null)
  } : null
}

output "cadvisor" {
  description = "cAdvisor outputs (null when disabled)."
  value = local.addon_enabled.cadvisor ? {
    service_name        = try(module.cadvisor_service[0].service_name, null)
    task_definition_arn = try(module.cadvisor_service[0].task_definition_arn, null)
  } : null
}

output "falco" {
  description = "Falco outputs (null when disabled)."
  value = local.addon_enabled.falco ? {
    service_name        = try(module.falco_service[0].service_name, null)
    task_definition_arn = try(module.falco_service[0].task_definition_arn, null)
  } : null
}

output "blackbox_exporter" {
  description = "Blackbox exporter outputs (null when disabled)."
  value = local.addon_enabled.blackbox_exporter ? {
    service_name        = try(module.blackbox_exporter_service[0].service_name, null)
    task_definition_arn = try(module.blackbox_exporter_service[0].task_definition_arn, null)
  } : null
}
