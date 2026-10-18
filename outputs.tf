output "cluster_id" {
  description = "ECS cluster ID (ARN)."
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "cluster_security_group_id" {
  description = "Cluster security group ID (tasks and node host ports join it)."
  value       = aws_security_group.this.id
}

output "capacity_provider_arns" {
  description = "ARNs of the EC2 capacity providers, keyed by node group name."
  value       = { for k, v in aws_ecs_capacity_provider.ec2 : k => v.arn }
}

output "node_groups" {
  description = "Node group outputs (ASG ARN/name), keyed by node group name."
  value = { for k, v in module.node_group : k => {
    autoscaling_group_arn  = v.autoscaling_group_arn
    autoscaling_group_name = v.autoscaling_group_name
  } }
}

output "services" {
  description = "Service outputs (name, task definition ARN/family), keyed by service name."
  value = { for k, v in module.service : k => {
    service_name           = v.service_name
    task_definition_arn    = v.task_definition_arn
    task_definition_family = v.task_definition_family
  } }
}

output "infrastructure_role_arn" {
  description = "ARN of the ECS infrastructure role (for EBS task volume management). Null when create_infrastructure_role is false and no override is provided."
  value       = var.infrastructure_role_arn != null ? var.infrastructure_role_arn : (var.create_infrastructure_role ? aws_iam_role.infrastructure[0].arn : null)
}

output "addons" {
  description = "Add-on outputs per enabled preset (null when cluster_addons is unset)."
  value = var.cluster_addons == null ? null : {
    traefik           = try(module.addons[0].traefik, null)
    opentelemetry     = try(module.addons[0].opentelemetry, null)
    cloudwatch_agent  = try(module.addons[0].cloudwatch_agent, null)
    fluent_bit        = try(module.addons[0].fluent_bit, null)
    node_exporter     = try(module.addons[0].node_exporter, null)
    cadvisor          = try(module.addons[0].cadvisor, null)
    falco             = try(module.addons[0].falco, null)
    blackbox_exporter = try(module.addons[0].blackbox_exporter, null)
    observability     = try(module.addons[0].observability, null)
  }
}
