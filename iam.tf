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
