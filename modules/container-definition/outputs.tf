output "container_definition" {
  description = "A single container definition object (camelCase keys, ECS API shape). Combine several into a list and jsonencode() for aws_ecs_task_definition.container_definitions."
  value       = local.final_container_definition
}

output "json" {
  description = "jsonencode() of this one container definition - not wrapped in a list."
  value       = jsonencode(local.final_container_definition)
}
