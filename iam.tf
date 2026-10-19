locals {
  shared_profile_node_groups = [
    for ng in values(var.node_groups) : ng
    if try(ng.iam, null) == null && try(ng.iam_instance_profile_name, null) == null
  ]

  shared_profile_registry_auths = [
    for ng in local.shared_profile_node_groups : try(ng.ecs_agent_config.registry_auth, null)
    if try(ng.ecs_agent_config.registry_auth, null) != null
  ]

  # try(): node_groups is type = any, so a registry password missing this
  # attribute is a static error without it (mixed password sources per group).
  instance_role_registry_sm_arns = flatten([
    for ra in local.shared_profile_registry_auths : [
      for c in values(ra.registries) : try(c.password.secretsmanager_secret_arn, null)
      if try(c.password.secretsmanager_secret_arn, null) != null
    ]
  ])

  instance_role_registry_kms_arns = flatten([
    for ra in local.shared_profile_registry_auths : [
      for c in values(ra.registries) : try(c.password.kms_key_arn, null)
      if try(c.password.kms_key_arn, null) != null
    ]
  ])

  instance_role_sm_arns  = concat(var.instance_role_least_privilege.secretsmanager_secret_arns, local.instance_role_registry_sm_arns)
  instance_role_kms_arns = concat(var.instance_role_least_privilege.kms_key_arns, local.instance_role_registry_kms_arns)

  # Derived from inputs, not the rendered JSON - the JSON is unknown whenever
  # a scoped ARN comes from a resource created in this same apply.
  instance_role_least_privilege_arns = concat(
    var.instance_role_least_privilege.ecr_registry_arns,
    local.instance_role_sm_arns,
    var.instance_role_least_privilege.ssm_parameter_arns,
    local.instance_role_kms_arns,
    var.instance_role_least_privilege.route53_hosted_zone_arns,
  )

  task_execution_least_privilege_arns = concat(
    var.task_execution_role_least_privilege.ecr_registry_arns,
    var.task_execution_role_least_privilege.secretsmanager_secret_arns,
    var.task_execution_role_least_privilege.ssm_parameter_arns,
    var.task_execution_role_least_privilege.kms_key_arns,
    var.task_execution_role_least_privilege.route53_hosted_zone_arns,
  )
}

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

  name                 = "${var.name}-instance"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role[0].json
  permissions_boundary = var.instance_role_permission_boundary_arn

  tags = local.tagger_tags["this"]
}

resource "aws_iam_role_policy_attachment" "instance" {
  for_each = var.create_instance_iam_role ? toset(concat(
    [
      "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    ],
    var.instance_role_managed_policy_arns,
  )) : toset([])

  role       = aws_iam_role.instance[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "instance_inline" {
  for_each = var.create_instance_iam_role ? var.instance_role_inline_policies : {}

  dynamic "statement" {
    for_each = each.value
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "instance_inline" {
  for_each = var.create_instance_iam_role ? var.instance_role_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.instance[0].id
  policy = data.aws_iam_policy_document.instance_inline[each.key].json
}

module "instance_least_privilege" {
  source = "./modules/iam-policy-documents"
  count  = var.create_instance_iam_role ? 1 : 0

  least_privilege = {
    ecr_registry_arns          = var.instance_role_least_privilege.ecr_registry_arns
    secretsmanager_secret_arns = local.instance_role_sm_arns
    ssm_parameter_arns         = var.instance_role_least_privilege.ssm_parameter_arns
    kms_key_arns               = local.instance_role_kms_arns
    route53_hosted_zone_arns   = var.instance_role_least_privilege.route53_hosted_zone_arns
  }
}

resource "aws_iam_role_policy" "instance_least_privilege" {
  count = var.create_instance_iam_role && length(local.instance_role_least_privilege_arns) > 0 ? 1 : 0

  name   = "least-privilege"
  role   = aws_iam_role.instance[0].id
  policy = module.instance_least_privilege[0].json
}

# EC2 tasks write awslogs via the INSTANCE role (execution role covers
# Fargate only); AmazonEC2ContainerServiceforEC2Role lacks the logs actions,
# so awslogs tasks fail at validation without this.
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
        "arn:aws:logs:${data.aws_region.current[0].region}:${data.aws_caller_identity.current[0].account_id}:log-group:/aws/ecs/${var.name}*",
        "arn:aws:logs:${data.aws_region.current[0].region}:${data.aws_caller_identity.current[0].account_id}:log-group:/aws/ecs/${var.name}*:log-stream:*",
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

  name                 = "${var.name}-task-execution"
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume_role[0].json
  permissions_boundary = var.task_execution_role_permission_boundary_arn

  tags = local.tagger_tags["this"]
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  for_each = var.create_task_execution_role ? toset(concat(
    ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"],
    var.task_execution_role_managed_policy_arns,
  )) : toset([])

  role       = aws_iam_role.task_execution[0].name
  policy_arn = each.value
}

data "aws_iam_policy_document" "task_execution_inline" {
  for_each = var.create_task_execution_role ? var.task_execution_role_inline_policies : {}

  dynamic "statement" {
    for_each = each.value
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "task_execution_inline" {
  for_each = var.create_task_execution_role ? var.task_execution_role_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.task_execution[0].id
  policy = data.aws_iam_policy_document.task_execution_inline[each.key].json
}

module "task_execution_least_privilege" {
  source = "./modules/iam-policy-documents"
  count  = var.create_task_execution_role ? 1 : 0

  least_privilege = var.task_execution_role_least_privilege
}

resource "aws_iam_role_policy" "task_execution_least_privilege" {
  count = var.create_task_execution_role && length(local.task_execution_least_privilege_arns) > 0 ? 1 : 0

  name   = "least-privilege"
  role   = aws_iam_role.task_execution[0].id
  policy = module.task_execution_least_privilege[0].json
}

# Lets ECS manage EBS volumes attached via configure_at_launch (create,
# attach, detach, delete) - without it, stopped tasks leave orphaned volumes.
# Skipped when infrastructure_role_arn supplies an existing role.
data "aws_iam_policy_document" "ecs_infrastructure_assume" {
  count = var.create_ecs_infrastructure_role && var.infrastructure_role_arn == null ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_infrastructure" {
  count = var.create_ecs_infrastructure_role && var.infrastructure_role_arn == null ? 1 : 0

  name               = "${var.name}-ecs-infrastructure"
  assume_role_policy = data.aws_iam_policy_document.ecs_infrastructure_assume[0].json

  tags = local.tagger_tags["this"]
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure" {
  count = var.create_ecs_infrastructure_role && var.infrastructure_role_arn == null ? 1 : 0

  role       = aws_iam_role.ecs_infrastructure[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForVolumes"
}

locals {
  ecs_infrastructure_role_arn = var.infrastructure_role_arn != null ? var.infrastructure_role_arn : try(aws_iam_role.ecs_infrastructure[0].arn, null)
}

check "node_group_registry_auth_coverage" {
  assert {
    condition = alltrue([
      for ng_key, ng in var.node_groups : (
        (try(ng.iam, null) == null && try(ng.iam_instance_profile_name, null) == null)
        || try(ng.iam.create, null) != null
        || try(ng.ecs_agent_config.registry_auth, null) == null
      )
    ])
    error_message = "One or more node_groups combine iam.use_existing or iam_instance_profile_name with ecs_agent_config.registry_auth (secretsmanager/kms-sourced password). This module has no role to attach the required IAM grant to - the ECS agent gets AccessDenied on secretsmanager:GetSecretValue at boot. Use iam.create for that node group, or grant the permission on the externally-supplied role yourself."
  }
}
