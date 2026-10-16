# CloudWatch log groups for addon tasks. The managed
# AmazonECSTaskExecutionRolePolicy does not grant logs:CreateLogGroup or
# logs:DescribeLogStreams, so the agent's awslogs-create-group=true path fails
# at task validation ("cannot find the log group") - the groups must exist
# before the task starts.

resource "aws_cloudwatch_log_group" "addon" {
  for_each = { for k in keys(local.addon_services) : k => k if contains([
    "traefik", "opentelemetry", "cloudwatch_agent", "fluent_bit",
    "node_exporter", "cadvisor", "falco", "blackbox_exporter",
  ], k) }

  name              = "/aws/ecs/${var.cluster_name}/addons/${each.key}"
  retention_in_days = 14

  tags = local.tagger_tags["loggroup-${each.key}"]
}
