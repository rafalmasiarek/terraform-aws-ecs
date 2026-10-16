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
  description = "List of volume configurations. Each entry: { name, host_path?, configure_at_launch?, efs_volume_configuration?, ebs_volume_configuration? }. EBS volumes require infrastructure_role_arn (or the cluster's default) for ECS to manage the volume lifecycle."
  type        = any
  default     = []
}

variable "infrastructure_role_arn" {
  description = "ARN of the ECS infrastructure role for EBS task volume management. Falls back to the cluster's default when null."
  type        = string
  default     = null
}

variable "desired_count" {
  type    = number
  default = 1
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

variable "scheduling_strategy" {
  description = "\"DAEMON\" (one task per active container instance) or \"REPLICA\" (the default)."
  type        = string
  default     = "REPLICA"
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

