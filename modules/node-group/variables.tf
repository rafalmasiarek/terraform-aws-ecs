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

variable "force_delete" {
  description = "Destroy the ASG without waiting for instances to terminate (skips graceful drain). Useful for fast teardown of disposable environments."
  type        = bool
  default     = false
}

variable "autoscaling_policies_enabled" {
  type    = bool
  default = false
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
