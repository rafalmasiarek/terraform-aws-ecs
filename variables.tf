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

variable "services" {
  description = "One ECS service + task definition per entry. See modules/service/variables.tf for the full per-entry shape - every field there is a key in this entry's object. container_definitions is typically built by calling this repo's modules/container-definition submodule once per container, outside this module."
  type        = any
  default     = {}
}

variable "create_infrastructure_role" {
  description = "Create the ECS infrastructure IAM role that allows Amazon ECS to manage EBS volumes attached to tasks (AmazonECSInfrastructureRolePolicyForVolumes). Set false and pass infrastructure_role_arn if you already manage this elsewhere."
  type        = bool
  default     = true
}

variable "infrastructure_role_arn" {
  description = "ARN of an existing ECS infrastructure role to use for EBS task volumes. When set, create_infrastructure_role is ignored."
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
