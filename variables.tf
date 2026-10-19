variable "name" {
  description = "ECS cluster name."
  type        = string
}

variable "vpc_id" {
  description = "VPC the cluster's SG and node groups live in."
  type        = string
}

variable "create_cloudwatch_log_group" {
  description = "Create a CloudWatch log group for cluster-level execute-command logging."
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_retention_in_days" {
  type    = number
  default = 30
}

variable "cloudwatch_log_group_name" {
  description = "Use an existing CloudWatch log group for execute-command logging instead of the module-created one (create_cloudwatch_log_group must be false)."
  type        = string
  default     = null

  validation {
    condition     = !(var.cloudwatch_log_group_name != null && var.create_cloudwatch_log_group)
    error_message = "Set cloudwatch_log_group_name or create_cloudwatch_log_group, not both."
  }
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "KMS key ID for encrypting the execute-command CloudWatch log group."
  type        = string
  default     = null
}

variable "exec_command_s3" {
  description = "ECS Exec logging to S3, in addition to or instead of CloudWatch Logs. Bucket and KMS key are create-or-use; when created they get a least-privilege key policy and SSE-KMS."
  type = object({
    bucket = object({
      create     = optional(bool, true)
      name       = optional(string)
      key_prefix = optional(string)
    })
    kms = optional(object({
      create = optional(bool, true)
      key_id = optional(string)
    }))
  })
  default = null

  validation {
    condition = var.exec_command_s3 == null ? true : can(element([for _ in [1] : 1 if(
      var.exec_command_s3.bucket.create || var.exec_command_s3.bucket.name != null
      ) && (
      var.exec_command_s3.kms == null || var.exec_command_s3.kms.create || var.exec_command_s3.kms.key_id != null
    )], 0))
    error_message = "exec_command_s3: the bucket needs create = true or a name; a kms block needs create = true or a key_id."
  }
}

variable "container_insights" {
  description = "Cluster-level Container Insights: \"disabled\", \"enabled\" or \"enhanced\". Null keeps the account default."
  type        = string
  default     = null

  validation {
    condition     = var.container_insights == null ? true : contains(["disabled", "enabled", "enhanced"], var.container_insights)
    error_message = "container_insights must be \"disabled\", \"enabled\" or \"enhanced\"."
  }
}

variable "default_capacity_provider_strategy" {
  description = "Cluster default capacity provider strategy - fallback for services that don't set their own. capacity_provider must be enabled on the cluster (a node-group capacity provider name or an fargate_capacity_providers entry)."
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 1)
    base              = optional(number)
  }))
  default = []

  validation {
    condition = can(element([for _ in [1] : 1 if alltrue([
      for s in var.default_capacity_provider_strategy : contains(
        concat([for k in keys(var.node_groups) : "${var.name}-${k}"], var.fargate_capacity_providers),
        s.capacity_provider,
      )
    ])], 0))
    error_message = "default_capacity_provider_strategy entries must reference a capacity provider enabled on this cluster."
  }

  validation {
    condition = can(element([for _ in [1] : 1 if(
      alltrue([for s in var.default_capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
      || alltrue([for s in var.default_capacity_provider_strategy : !contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
    )], 0))
    error_message = "default_capacity_provider_strategy cannot mix FARGATE/FARGATE_SPOT with node-group capacity providers (AWS rejects mixed strategies)."
  }
}

variable "account_settings" {
  description = "ECS account default settings (name => value) - account-wide and per-Region, explicit opt-in. See modules/account-settings for the writable names and allowed values."
  type        = map(string)
  default     = {}
}

variable "fargate_capacity_providers" {
  description = "Subset of [\"FARGATE\", \"FARGATE_SPOT\"] to enable on this cluster. AWS-managed - no resources created for these."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cp in var.fargate_capacity_providers : contains(["FARGATE", "FARGATE_SPOT"], cp)])
    error_message = "fargate_capacity_providers may only contain \"FARGATE\" and/or \"FARGATE_SPOT\"."
  }
}

variable "node_groups" {
  description = "EC2-backed capacity providers. Each entry creates one terraform-aws-ec2-autoscale-group instance (modules/node-group) plus one ECS capacity provider wired to it. See modules/node-group/variables.tf for the full per-entry shape - every field there is a key in this entry's object."
  type        = any
  default     = {}
}

variable "create_instance_iam_role" {
  description = "Create the shared IAM role/instance profile EC2 node groups attach to (AmazonEC2ContainerServiceforEC2Role + AmazonSSMManagedInstanceCore). Set false and pass iam_instance_profile_name per node group yourself if you already manage this elsewhere."
  type        = bool
  default     = true
}

variable "create_task_execution_role" {
  description = "Create a default ECS task execution role (AmazonECSTaskExecutionRolePolicy) that modules/service falls back to when a task doesn't specify its own execution_role_arn."
  type        = bool
  default     = true
}

variable "alb_security_group_id" {
  description = "Security group of an existing ALB/NLB, if any - opens the ephemeral port range (32768-61000) from it to the cluster's own SG. This module never creates the load balancer itself."
  type        = string
  default     = null
}

variable "tg_health_check_port" {
  description = "ALB target-group health-check port, opened from alb_security_group_id in addition to the ephemeral range, if different from \"traffic-port\"."
  type        = string
  default     = null
}

variable "task_sg_ingress_rules" {
  description = "Declarative ingress rules for the cluster's task SG (<name>-tasks) - the SG is attached to every node group instance and awsvpc task ENI, so rules here open ports at the node level (bridge-mode host ports) and the task level alike. Modelled on terraform-aws-eks node-group security_group_ingress_rules: the map key is the rule's stable identity, from_port/to_port are strings, omit to_port for a single port, self = true references the task SG itself."
  type = map(object({
    name                         = optional(string)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(string)
    ip_protocol                  = optional(string)
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    self                         = optional(bool)
    tags                         = optional(map(string), {})
    to_port                      = optional(string)
  }))
  default = {}
}

variable "task_sg_egress_rules" {
  description = "Declarative egress rules for the cluster's task SG (<name>-tasks) - same shape and semantics as task_sg_ingress_rules (modelled on terraform-aws-eks node-group security_group_egress_rules). The task SG already has an allow-all egress rule; use this to add specific egress entries anyway, e.g. for auditing."
  type = map(object({
    name                         = optional(string)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(string)
    ip_protocol                  = optional(string)
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    self                         = optional(bool)
    tags                         = optional(map(string), {})
    to_port                      = optional(string)
  }))
  default = {}
}

variable "services" {
  description = "One ECS service + task definition per entry. See modules/service/variables.tf for the full per-entry shape - every field there is a key in this entry's object. container_definitions is typically built by calling this repo's modules/container-definition submodule once per container, outside this module. Root-level extras: open_task_ports = { source_cidr_ipv4?, source_cidr_ipv6?, source_security_group_id? } auto-opens the entry's container port mappings (bridge: hostPort, awsvpc/Fargate: containerPort) on the cluster's task SG, tagged with the service identity - opt-in per entry, omitted = no ingress rules. source_security_group_id models an ALB/NLB or any other internal ingress SG; source_cidr_ipv4/ipv6 model a plain CIDR source. At least one of the three is required when open_task_ports is set."
  type        = any
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.services : try(v.open_task_ports, null) == null ? true : (
        try(v.open_task_ports.source_cidr_ipv4, null) != null
        || try(v.open_task_ports.source_cidr_ipv6, null) != null
        || try(v.open_task_ports.source_security_group_id, null) != null
      )
    ])
    error_message = "services[<key>].open_task_ports is set but has none of source_cidr_ipv4, source_cidr_ipv6, or source_security_group_id - it would silently open no ingress rule."
  }
}

variable "instance_role_permission_boundary_arn" {
  type    = string
  default = null
}

variable "instance_role_managed_policy_arns" {
  description = "Extra managed policies for the shared instance role, on top of the base ECS + SSM policies."
  type        = list(string)
  default     = []
}

variable "instance_role_inline_policies" {
  description = "Policy name => statements; each entry becomes one inline policy on the shared instance role."
  type = map(list(object({
    sid       = optional(string)
    effect    = string
    actions   = list(string)
    resources = list(string)
  })))
  default = {}
}

variable "instance_role_least_privilege" {
  description = "Scoped ARN lists for the shared instance role. Node groups using the shared profile auto-add their registry_auth Secrets Manager and KMS ARNs on top."
  type = object({
    ecr_registry_arns          = optional(list(string), [])
    secretsmanager_secret_arns = optional(list(string), [])
    ssm_parameter_arns         = optional(list(string), [])
    kms_key_arns               = optional(list(string), [])
    route53_hosted_zone_arns   = optional(list(string), [])
  })
  default = {
    ecr_registry_arns          = []
    secretsmanager_secret_arns = []
    ssm_parameter_arns         = []
    kms_key_arns               = []
    route53_hosted_zone_arns   = []
  }
}

variable "task_execution_role_permission_boundary_arn" {
  type    = string
  default = null
}

variable "task_execution_role_managed_policy_arns" {
  description = "Extra managed policies for the shared task execution role, on top of AmazonECSTaskExecutionRolePolicy."
  type        = list(string)
  default     = []
}

variable "task_execution_role_inline_policies" {
  description = "Policy name => statements; each entry becomes one inline policy on the shared task execution role."
  type = map(list(object({
    sid       = optional(string)
    effect    = string
    actions   = list(string)
    resources = list(string)
  })))
  default = {}
}

variable "task_execution_role_least_privilege" {
  type = object({
    ecr_registry_arns          = optional(list(string), [])
    secretsmanager_secret_arns = optional(list(string), [])
    ssm_parameter_arns         = optional(list(string), [])
    kms_key_arns               = optional(list(string), [])
    route53_hosted_zone_arns   = optional(list(string), [])
  })
  default = {
    ecr_registry_arns          = []
    secretsmanager_secret_arns = []
    ssm_parameter_arns         = []
    kms_key_arns               = []
    route53_hosted_zone_arns   = []
  }
}

variable "create_ecs_infrastructure_role" {
  description = "Create the ECS infrastructure role (AmazonECSInfrastructureRolePolicyForVolumes) - the default role_arn for services' managed_ebs_volume entries. Ignored when infrastructure_role_arn is set."
  type        = bool
  default     = false
}

variable "infrastructure_role_arn" {
  description = "ARN of an existing ECS infrastructure role to use for EBS task volumes instead of creating one. When set, create_ecs_infrastructure_role is ignored."
  type        = string
  default     = null
}

variable "cluster_addons" {
  description = "ECS cluster infrastructure add-ons: traefik, opentelemetry, cloudwatch_agent, fluent_bit, node_exporter, cadvisor, falco, blackbox_exporter. Omit (null) to disable all. See docs/addons.md and modules/addons/variables.tf for the full schema and per-preset semantics."
  type        = any
  default     = null

  # Unknown top-level keys are rejected here; unknown per-preset attributes
  # fail the plan at the first HCL attribute access inside the module.
  validation {
    condition = var.cluster_addons == null ? true : alltrue([
      for k in keys(var.cluster_addons) : contains(
        ["traefik", "opentelemetry", "cloudwatch_agent", "fluent_bit",
      "node_exporter", "cadvisor", "falco", "blackbox_exporter", "observability"], k)
    ])
    error_message = "cluster_addons: unknown preset. Valid keys: traefik, opentelemetry, cloudwatch_agent, fluent_bit, node_exporter, cadvisor, falco, blackbox_exporter, observability."
  }
}
