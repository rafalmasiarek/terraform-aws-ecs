data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ec2_assume_role" {
  count = var.create_instance_iam_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  count = var.create_instance_iam_role ? 1 : 0

  name               = "${var.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role[0].json

  tags = local.tagger_tags["this"]
}

resource "aws_iam_role_policy_attachment" "instance_ecs" {
  count = var.create_instance_iam_role ? 1 : 0

  role       = aws_iam_role.instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "instance_ssm" {
  count = var.create_instance_iam_role ? 1 : 0

  role       = aws_iam_role.instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# On EC2 the container agent writes task logs to CloudWatch with the
# INSTANCE role's credentials (the execution role covers Fargate). The
# managed AmazonEC2ContainerServiceforEC2Role does not grant the logs
# actions, so tasks using the awslogs driver fail at validation
# ("cannot find the log group"). Scoped to this cluster's log groups.
resource "aws_iam_role_policy" "instance_awslogs" {
  count = var.create_instance_iam_role ? 1 : 0

  name = "${var.name}-instance-awslogs"
  role = aws_iam_role.instance[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:PutLogEvents"]
      Resource = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/${var.name}*",
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/${var.name}*:log-stream:*",
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "instance" {
  count = var.create_instance_iam_role ? 1 : 0

  name = "${var.name}-instance"
  role = aws_iam_role.instance[0].name

  tags = local.tagger_tags["this"]
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  count = var.create_task_execution_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  count = var.create_task_execution_role ? 1 : 0

  name               = "${var.name}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role[0].json

  tags = local.tagger_tags["this"]
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  count = var.create_task_execution_role ? 1 : 0

  role       = aws_iam_role.task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
