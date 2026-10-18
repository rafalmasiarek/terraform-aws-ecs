variable "cluster_name" {
  description = "ECS cluster this node group joins (used to build the ECS agent's user_data)."
  type        = string
}

variable "name" {
  description = "Node group name - becomes the ASG + launch template name."
  type        = string
}

variable "ami_id" {
  description = "Explicit AMI (e.g. a Marketplace/custom image). Falls back to the official AL2023 ECS-optimized AMI via SSM, arch-matched to instance_type, when null."
  type        = string
  default     = null
}

variable "instance_type" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "associate_public_ip_address" {
  type    = bool
  default = false
}

variable "iam_instance_profile_name" {
  type = string
}

variable "key_name" {
  type    = string
  default = null
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type    = number
  default = null
}

variable "mixed_instances_policy" {
  type    = any
  default = null
}

variable "instance_refresh" {
  type = any
  default = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 66
    }
  }
}

variable "block_device_mappings" {
  type    = any
  default = []
}

variable "cloudinit_config" {
  description = "Wildcard passthrough to every input of terraform-aws-ec2-cloudinit (cloud_config, packages, users, files, mounts, ansible_pull, artifacts, ansible_playbooks, ...), merged with this module's own mandatory ECS agent bootstrap script - the bootstrap script always runs last, after any cloudinit_parts set here, to guarantee the node actually joins the cluster regardless of what comes before it."
  type        = any
  default     = {}
}

variable "autoscaling_policies_enabled" {
  type    = bool
  default = false
}

variable "protect_from_scale_in" {
  description = "ASG ProtectFromScaleIn flag for the nodes. True (default) is required for ECS managed termination protection to work (the agent drains tasks and deregisters the container instance before shutdown). While every instance is protected, ASG cannot scale in on its own - set false to allow ASG-initiated scale-in."
  type        = bool
  default     = true
}

variable "use_tagger" {
  type    = bool
  default = true
}

variable "tagger_context" {
  type    = any
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "ecs_agent_config" {
  description = "ECS Container Agent configuration appended to /etc/ecs/ecs.config at first boot - generic environment passthrough plus structurally built registry auth; a first-boot systemd unit then enables and starts the packaged ecs unit. See docs/rfc-ecs-agent-registry-auth.md."
  type = object({
    environment = optional(map(string), {})
    registry_auth = optional(object({
      type = string
      registries = map(object({
        username = string
        password = object({
          plaintext                 = optional(string)
          file                      = optional(string)
          secretsmanager_secret_arn = optional(string)
          kms_key_arn               = optional(string)
        })
        email = optional(string)
      }))
    }))
  })
  default = null

  validation {
    condition = var.ecs_agent_config == null ? true : can(element([for _ in [1] : 1 if alltrue([
      for k, v in coalesce(var.ecs_agent_config.environment, {}) : can(regex("^[A-Z][A-Z0-9_]*$", k)) && !strcontains(v, "\n") && !strcontains(v, "\r")
    ])], 0))
    error_message = "ecs_agent_config.environment keys must match ^[A-Z][A-Z0-9_]*$ and values must be single-line strings."
  }

  validation {
    condition = var.ecs_agent_config == null ? true : can(element([for _ in [1] : 1 if length([
      for k in keys(coalesce(var.ecs_agent_config.environment, {})) : k
      if contains(["ECS_CLUSTER", "ECS_ENGINE_AUTH_TYPE", "ECS_ENGINE_AUTH_DATA"], k)
    ]) == 0], 0))
    error_message = "ECS_CLUSTER, ECS_ENGINE_AUTH_TYPE and ECS_ENGINE_AUTH_DATA are module-owned - use the module's cluster_name and ecs_agent_config.registry_auth instead."
  }

  validation {
    condition = var.ecs_agent_config == null ? true : can(element([for _ in [1] : 1 if var.ecs_agent_config.registry_auth == null || (
      contains(["docker", "dockercfg"], var.ecs_agent_config.registry_auth.type)
      && length(var.ecs_agent_config.registry_auth.registries) > 0
    )], 0))
    error_message = "ecs_agent_config.registry_auth.type must be \"docker\" or \"dockercfg\" and registries must have at least one entry."
  }

  validation {
    condition = var.ecs_agent_config == null ? true : can(element([for _ in [1] : 1 if var.ecs_agent_config.registry_auth == null || alltrue([
      for reg, c in var.ecs_agent_config.registry_auth.registries : can(element([for _ in [1] : 1 if(
        reg != "" && !can(regex("[[:space:]]", reg))
        && ((c.password.plaintext == null ? 0 : 1) + (c.password.file == null ? 0 : 1) + (c.password.secretsmanager_secret_arn == null ? 0 : 1)) == 1
        && (c.password.kms_key_arn == null || c.password.secretsmanager_secret_arn != null)
      )], 0))
    ])], 0))
    error_message = "Each registry needs a non-empty name without whitespace and exactly one password source (plaintext, file or secretsmanager_secret_arn); password.kms_key_arn is only valid with the secretsmanager_secret_arn source."
  }
}

variable "iam" {
  description = "Create-or-use for this node group's instance role + profile, overriding the shared root role. Omit to keep the shared role."
  type = object({
    use_existing = optional(object({
      instance_profile_name = string
    }))
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
    condition     = var.iam == null ? true : can(element([for _ in [1] : 1 if var.iam.use_existing == null || var.iam.create == null], 0))
    error_message = "Set at most one of iam.use_existing and iam.create."
  }

  validation {
    condition     = try(var.iam.create, null) != null || try(var.iam.use_existing, null) != null || var.iam_instance_profile_name != null
    error_message = "No instance profile source: set iam.create, iam.use_existing, or iam_instance_profile_name. Without one of these, node_role_profile_name resolves to coalesce(null, null) and crashes the plan."
  }
}
