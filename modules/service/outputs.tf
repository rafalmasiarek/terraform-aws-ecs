output "service_name" {
  value = aws_ecs_service.this.name
}

output "service_id" {
  value = aws_ecs_service.this.id
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  value = aws_ecs_task_definition.this.family
}

output "task_execution_role_arn" {
  value = try(module.task_execution_role[0].arn, null)
}

output "task_role_arn" {
  value = try(module.task_role[0].arn, null)
}
