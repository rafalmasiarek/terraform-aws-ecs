# The shared instance/execution role attachments were re-keyed from
# count-based resources to for_each keyed by policy ARN.
moved {
  from = aws_iam_role_policy_attachment.instance_ecs[0]
  to   = aws_iam_role_policy_attachment.instance["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"]
}

moved {
  from = aws_iam_role_policy_attachment.instance_ssm[0]
  to   = aws_iam_role_policy_attachment.instance["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

moved {
  from = aws_iam_role_policy_attachment.task_execution[0]
  to   = aws_iam_role_policy_attachment.task_execution["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}
