output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cloudwatch_log_group_name" {
  value = local.exec_cwl_name
}

output "exec_s3_bucket_name" {
  value = local.exec_s3_bucket_name
}

output "exec_s3_bucket_arn" {
  value = local.exec_s3_bucket_arn
}

output "exec_kms_key_id" {
  value = local.exec_kms_key_id
}

output "ecs_infrastructure_role_arn" {
  value = var.create_ecs_infrastructure_role ? try(aws_iam_role.ecs_infrastructure[0].arn, null) : null
}
