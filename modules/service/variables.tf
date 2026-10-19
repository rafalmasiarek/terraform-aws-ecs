variable "cluster_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "name" {
  type = string
}

variable "container_definitions" {
  description = "List of container definition objects, e.g. from modules/container-definition's `container_definition` output - one entry per container in the task."
  type        = any
}

variable "task_cpu" {
  type    = number
  default = null
}

variable "task_memory" {
  type    = number
  default = null
}

variable "network_mode" {
  type    = string
  default = "awsvpc"
}

variable "requires_compatibilities" {
  type    = list(string)
  default = ["FARGATE"]
}

variable "task_role_arn" {
  type    = string
  default = null
}

variable "execution_role_arn" {
  description = "Falls back to default_execution_role_arn when null."
  type        = string
  default     = null
}

variable "default_execution_role_arn" {
  description = "The cluster's default task execution role ARN (root module's aws_iam_role.task_execution output), used when execution_role_arn is null."
  type        = string
}

variable "volumes" {
  type    = any
  default = []

  validation {
    condition = can(element([for _ in [1] : 1 if length([
      for v in var.volumes : v
      if try(v.configure_at_launch, false) == true
    ]) <= 1], 0))
    error_message = "At most one volume may set configure_at_launch = true (ECS managed EBS limit: one configured-at-launch volume per task definition)."
  }
}

variable "desired_count" {
  description = "REPLICA only - defaults to 1; DAEMON services must not set it (null)."
  type        = number
  default     = null
}

variable "scheduling_strategy" {
  description = "\"REPLICA\" or \"DAEMON\". DAEMON deploys one task per eligible EC2 container instance: EC2 capacity only, no desired_count, no service autoscaling, no ordered placement strategy, deployment percentages pinned to 100/0."
  type        = string
  default     = "REPLICA"

  validation {
    condition     = contains(["REPLICA", "DAEMON"], var.scheduling_strategy)
    error_message = "scheduling_strategy must be \"REPLICA\" or \"DAEMON\"."
  }

  validation {
    condition = var.scheduling_strategy != "DAEMON" ? true : can(element([for _ in [1] : 1 if(
      var.desired_count == null
      && !var.autoscaling_enabled
      && length(var.ordered_placement_strategy) == 0
      && length(var.capacity_provider_strategy) == 0
      && var.launch_type != "FARGATE"
    )], 0))
    error_message = "DAEMON services cannot use launch_type = \"FARGATE\" (EC2 or EXTERNAL only) and must not set desired_count, autoscaling_enabled, ordered_placement_strategy, or capacity_provider_strategy (AWS rejects any capacity provider strategy on DAEMON services)."
  }
}

variable "deployment_circuit_breaker" {
  type = object({
    enable   = bool
    rollback = optional(bool, true)
  })
  default = null
}

variable "deployment_controller_type" {
  description = "\"ECS\" or \"CODE_DEPLOY\" - null keeps the default ECS controller."
  type        = string
  default     = null

  validation {
    condition     = var.deployment_controller_type == null ? true : contains(["ECS", "CODE_DEPLOY"], var.deployment_controller_type)
    error_message = "deployment_controller_type must be \"ECS\" or \"CODE_DEPLOY\"."
  }
}

variable "enable_ecs_managed_tags" {
  type    = bool
  default = false
}

variable "propagate_tags" {
  description = "Propagate tags from the service or task definition to the task: \"SERVICE\", \"TASK_DEFINITION\" or \"NONE\"."
  type        = string
  default     = null

  validation {
    condition     = var.propagate_tags == null ? true : contains(["SERVICE", "TASK_DEFINITION", "NONE"], var.propagate_tags)
    error_message = "propagate_tags must be \"SERVICE\", \"TASK_DEFINITION\" or \"NONE\"."
  }
}

variable "service_connect" {
  description = "ECS Service Connect configuration - requires network_mode = \"awsvpc\" (Fargate) or \"bridge\" (EC2)."
  type = object({
    namespace = string
    enabled   = optional(bool, true)
    service = optional(list(object({
      discovery_name        = string
      port_name             = optional(string)
      ingress_port_override = optional(number)
      client_alias = optional(list(object({
        dns_name = string
        port     = number
      })), [])
    })), [])
  })
  default = null

  validation {
    condition     = var.service_connect == null ? true : contains(["awsvpc", "bridge"], var.network_mode)
    error_message = "service_connect requires network_mode = \"awsvpc\" (Fargate) or \"bridge\" (EC2)."
  }

  validation {
    condition = var.service_connect == null ? true : can(element([for _ in [1] : 1 if(
      !var.service_connect.enabled
      || alltrue([for s in var.service_connect.service : length(s.client_alias) == 1])
    )], 0))
    error_message = "Each enabled service_connect service entry needs exactly one client_alias (AWS allows at most one per entry). Client-only services can omit the service list entirely."
  }
}

variable "launch_type" {
  description = "\"FARGATE\" or \"EC2\". Ignored (set to null) when capacity_provider_strategy is non-empty."
  type        = string
  default     = "FARGATE"
}

variable "capacity_provider_strategy" {
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 1)
    base              = optional(number)
  }))
  default = []

  validation {
    condition = can(element([for _ in [1] : 1 if(
      alltrue([for s in var.capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
      || alltrue([for s in var.capacity_provider_strategy : !contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
    )], 0))
    error_message = "capacity_provider_strategy cannot mix FARGATE/FARGATE_SPOT with other capacity providers (AWS rejects mixed strategies)."
  }
}

variable "deployment_maximum_percent" {
  type    = number
  default = 200
}

variable "deployment_minimum_healthy_percent" {
  type    = number
  default = 100
}

variable "health_check_grace_period_seconds" {
  type    = number
  default = null
}

variable "enable_execute_command" {
  type    = bool
  default = false
}

variable "wait_for_steady_state" {
  type    = bool
  default = false
}

variable "force_new_deployment" {
  type    = bool
  default = false
}

variable "load_balancer" {
  description = "Pure pass-through - target_group_arn comes from an ALB/NLB created elsewhere, never by this module."
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  default = []
}

variable "network_configuration" {
  description = "Required when network_mode = \"awsvpc\" (Fargate, or EC2 with awsvpc)."
  type = object({
    subnets          = list(string)
    security_groups  = optional(list(string), [])
    assign_public_ip = optional(bool, false)
  })
  default = null

  validation {
    condition     = var.network_mode != "awsvpc" || var.network_configuration != null
    error_message = "network_configuration is required when network_mode = \"awsvpc\" (the default) - without it the task has no subnets to launch into."
  }
}

variable "service_registries" {
  description = "Cloud Map service discovery registration."
  type = list(object({
    registry_arn   = string
    port           = optional(number)
    container_name = optional(string)
    container_port = optional(number)
  }))
  default = []
}

variable "placement_constraints" {
  type = list(object({
    type       = string
    expression = optional(string)
  }))
  default = []
}

variable "ordered_placement_strategy" {
  type = list(object({
    type  = string
    field = optional(string)
  }))
  default = []
}

# --- Service autoscaling (opt-in) - Application Auto Scaling target
# tracking on the ECS SERVICE's task count. Unrelated to the EC2 ASG's own
# instance-count autoscaling in terraform-aws-ec2-autoscale-group - this
# scales tasks, that scales machines. ---

variable "autoscaling_enabled" {
  type    = bool
  default = false
}

variable "autoscaling_min_capacity" {
  type    = number
  default = 1
}

variable "autoscaling_max_capacity" {
  type    = number
  default = 2
}

variable "cpu_target_tracking" {
  description = "Target CPU utilization % to scale the task count around. Null disables CPU-based tracking."
  type        = number
  default     = 70
}

variable "memory_target_tracking" {
  description = "Target memory utilization % to scale the task count around. Null disables memory-based tracking."
  type        = number
  default     = null
}

variable "scale_in_cooldown_seconds" {
  type    = number
  default = 300
}

variable "scale_out_cooldown_seconds" {
  type    = number
  default = 60
}

variable "alb_target_tracking" {
  description = "Target tracking on ALB request count. resource_label is the target group's Application Auto Scaling resource label (<target-group-arn>/<priority>)."
  type = object({
    target_value   = number
    resource_label = string
  })
  default = null

  validation {
    condition     = (var.alb_target_tracking == null && var.custom_metric_target_tracking == null && length(var.scheduled_actions) == 0) || var.autoscaling_enabled
    error_message = "alb_target_tracking, custom_metric_target_tracking and scheduled_actions require autoscaling_enabled = true (a scalable target must exist)."
  }
}

variable "custom_metric_target_tracking" {
  description = "Target tracking on a CloudWatch custom metric."
  type = object({
    metric_name  = string
    namespace    = string
    statistic    = string
    unit         = optional(string)
    target_value = number
    dimensions = list(object({
      name  = string
      value = string
    }))
  })
  default = null
}

variable "scheduled_actions" {
  description = "Application Auto Scaling scheduled actions (require autoscaling_enabled). Names must be unique per target."
  type = list(object({
    name         = string
    schedule     = string
    timezone     = optional(string)
    min_capacity = number
    max_capacity = number
  }))
  default = []
}

variable "runtime_platform" {
  type = object({
    cpu_architecture        = optional(string)
    operating_system_family = optional(string)
  })
  default = null
}

variable "ephemeral_storage_gib" {
  type    = number
  default = null
}

variable "pid_mode" {
  type    = string
  default = null

  validation {
    condition     = var.pid_mode == null ? true : contains(["host", "task"], var.pid_mode)
    error_message = "pid_mode must be \"host\" or \"task\"."
  }
}

variable "ipc_mode" {
  type    = string
  default = null

  validation {
    condition     = var.ipc_mode == null ? true : contains(["host", "task"], var.ipc_mode)
    error_message = "ipc_mode must be \"host\" or \"task\"."
  }
}

variable "enable_fault_injection" {
  type    = bool
  default = false
}

variable "proxy_configuration" {
  description = "Task-level sidecar proxy (e.g. App Mesh). properties are opaque key/value pairs."
  type = object({
    type           = string
    container_name = string
    properties     = optional(map(string), {})
  })
  default = null
}

variable "managed_ebs_volume" {
  description = "ECS-managed EBS volume per task - references a volumes entry with configure_at_launch = true. role_arn is the ECS infrastructure role (AmazonECSInfrastructureRolePolicyForVolumes); falls back to default_ecs_infrastructure_role_arn. tag_specifications tags the runtime-created volume (defaults to propagating the service's tags); the volume is created by ECS, so only AWS reserved tags, ECS managed tags (enable_ecs_managed_tags) and these specifications can reach it. Provider 6.x does not expose termination_policy."
  type = object({
    volume_name                = string
    role_arn                   = optional(string)
    encrypted                  = optional(bool, true)
    volume_type                = optional(string)
    size_in_gb                 = optional(number)
    iops                       = optional(number)
    throughput                 = optional(number)
    snapshot_id                = optional(string)
    kms_key_id                 = optional(string)
    file_system_type           = optional(string)
    volume_initialization_rate = optional(number)
    tag_specifications = optional(list(object({
      resource_type  = optional(string, "volume")
      tags           = optional(map(string))
      propagate_tags = optional(string)
      })), [{
      propagate_tags = "SERVICE"
    }])
  })
  default = null

  validation {
    condition = var.managed_ebs_volume == null ? true : can(element([for _ in [1] : 1 if anytrue([
      for v in var.volumes : try(v.name, "") == var.managed_ebs_volume.volume_name && try(v.configure_at_launch, false) == true
    ])], 0))
    error_message = "managed_ebs_volume.volume_name must reference a volumes entry with configure_at_launch = true."
  }

  validation {
    condition = var.managed_ebs_volume == null ? true : can(element([for _ in [1] : 1 if coalesce(
      var.managed_ebs_volume.role_arn,
      var.default_ecs_infrastructure_role_arn,
    ) != null], 0))
    error_message = "managed_ebs_volume needs a role_arn (ECS infrastructure role) or the module's default_ecs_infrastructure_role_arn."
  }

  validation {
    condition = var.managed_ebs_volume == null ? true : alltrue([
      for ts in var.managed_ebs_volume.tag_specifications :
      length(coalesce(ts.tags, {})) > 0 || ts.propagate_tags != null
    ])
    error_message = "managed_ebs_volume.tag_specifications entries need at least one of tags or propagate_tags."
  }
}

variable "default_ecs_infrastructure_role_arn" {
  description = "ECS infrastructure role ARN used by managed_ebs_volume when it sets no role_arn of its own."
  type        = string
  default     = null
}

variable "task_execution_role" {
  description = "Create-or-use task execution role, overriding execution_role_arn / default_execution_role_arn. At most one of arn / create."
  type = object({
    arn = optional(string)
    create = optional(object({
      name                    = optional(string)
      permission_boundary_arn = optional(string)
      managed_policy_arns     = optional(list(string), [])
      inline_policies = optional(map(list(object({
        sid       = optional(string)
        effect    = string
        actions   = list(string)
        resources = list(string)
      }))), {})
      least_privilege = optional(object({
        ecr_registry_arns          = optional(list(string), [])
        secretsmanager_secret_arns = optional(list(string), [])
        ssm_parameter_arns         = optional(list(string), [])
        kms_key_arns               = optional(list(string), [])
        route53_hosted_zone_arns   = optional(list(string), [])
        }), {
        ecr_registry_arns          = []
        secretsmanager_secret_arns = []
        ssm_parameter_arns         = []
        kms_key_arns               = []
        route53_hosted_zone_arns   = []
      })
    }))
  })
  default = null

  validation {
    condition     = var.task_execution_role == null ? true : can(element([for _ in [1] : 1 if var.task_execution_role.arn == null || var.task_execution_role.create == null], 0))
    error_message = "Set at most one of task_execution_role.arn and task_execution_role.create."
  }

  validation {
    condition     = can(element([for _ in [1] : 1 if var.execution_role_arn == null || var.task_execution_role == null], 0))
    error_message = "Use either execution_role_arn or task_execution_role, not both."
  }
}

variable "task_role" {
  description = "Create-or-use task role, overriding task_role_arn. At most one of arn / create."
  type = object({
    arn = optional(string)
    create = optional(object({
      name                    = optional(string)
      permission_boundary_arn = optional(string)
      managed_policy_arns     = optional(list(string), [])
      inline_policies = optional(map(list(object({
        sid       = optional(string)
        effect    = string
        actions   = list(string)
        resources = list(string)
      }))), {})
      least_privilege = optional(object({
        ecr_registry_arns          = optional(list(string), [])
        secretsmanager_secret_arns = optional(list(string), [])
        ssm_parameter_arns         = optional(list(string), [])
        kms_key_arns               = optional(list(string), [])
        route53_hosted_zone_arns   = optional(list(string), [])
        }), {
        ecr_registry_arns          = []
        secretsmanager_secret_arns = []
        ssm_parameter_arns         = []
        kms_key_arns               = []
        route53_hosted_zone_arns   = []
      })
    }))
  })
  default = null

  validation {
    condition     = var.task_role == null ? true : can(element([for _ in [1] : 1 if var.task_role.arn == null || var.task_role.create == null], 0))
    error_message = "Set at most one of task_role.arn and task_role.create."
  }

  validation {
    condition     = can(element([for _ in [1] : 1 if var.task_role_arn == null || var.task_role == null], 0))
    error_message = "Use either task_role_arn or task_role, not both."
  }

  # A task role is only strictly required for features that need it - ECS
  # Exec. Fargate tasks that do not call AWS APIs (and have Exec disabled) run
  # fine without a task role, so no launch-type-based requirement.
  validation {
    condition     = var.enable_execute_command ? (var.task_role_arn != null || var.task_role != null) : true
    error_message = "ECS Exec (enable_execute_command = true) requires a task role with SSM permissions - set task_role_arn or task_role."
  }
}

