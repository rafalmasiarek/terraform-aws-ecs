variable "container_name" {
  type = string
}

variable "image" {
  type = string
}

variable "essential" {
  type    = bool
  default = true
}

variable "cpu" {
  type    = number
  default = null
}

variable "memory" {
  type    = number
  default = null
}

variable "memory_reservation" {
  type    = number
  default = null
}

variable "entrypoint" {
  type    = list(string)
  default = null
}

variable "command" {
  type    = list(string)
  default = null
}

variable "working_directory" {
  type    = string
  default = null
}

variable "readonly_root_filesystem" {
  type    = bool
  default = null
}

variable "user" {
  type    = string
  default = null
}

variable "port_mappings" {
  type = list(object({
    container_port = number
    host_port      = optional(number)
    protocol       = optional(string, "tcp")
    name           = optional(string)
  }))
  default = []
}

variable "environment" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Environment variables sourced from Secrets Manager/SSM Parameter Store - map of env var name to ARN."
  type        = map(string)
  default     = {}
}

variable "log_configuration" {
  type = object({
    log_driver = string
    options    = optional(map(string), {})
    secret_options = optional(list(object({
      name       = string
      value_from = string
    })))
  })
  default = null
}

variable "health_check" {
  type = object({
    command      = list(string)
    interval     = optional(number, 30)
    timeout      = optional(number, 5)
    retries      = optional(number, 3)
    start_period = optional(number)
  })
  default = null
}

variable "depends_on_containers" {
  description = "Startup order within the same task - not Terraform's depends_on."
  type = list(object({
    container_name = string
    condition      = string
  }))
  default = []
}

variable "mount_points" {
  type = list(object({
    source_volume  = string
    container_path = string
    read_only      = optional(bool, false)
  }))
  default = []
}

variable "linux_parameters" {
  type = object({
    init_process_enabled = optional(bool)
    shared_memory_size   = optional(number)
  })
  default = null
}

variable "docker_labels" {
  type    = map(string)
  default = {}
}

variable "firelens_configuration" {
  description = "FireLens log routing (e.g. splunk/syslog router container)."
  type = object({
    type    = string
    options = map(string)
  })
  default = null

  validation {
    condition     = var.firelens_configuration == null ? true : contains(["fluentd", "fluentbit"], var.firelens_configuration.type)
    error_message = "firelens_configuration.type must be \"fluentd\" or \"fluentbit\"."
  }
}

variable "repository_credentials" {
  description = "ARN of a Secrets Manager secret holding the private registry credentials for pulling this image (rendered as repositoryCredentials.credentialsParameter). The task execution role needs secretsmanager:GetSecretValue on it."
  type        = string
  default     = null
}

variable "ulimits" {
  type = list(object({
    name       = string
    soft_limit = number
    hard_limit = number
  }))
  default = []
}

variable "system_controls" {
  type = list(object({
    namespace = string
    value     = string
  }))
  default = []
}

variable "resource_requirements" {
  type = list(object({
    type  = string
    value = string
  }))
  default = []
}

variable "extra_fields" {
  description = "Escape hatch for any ECS container-definition field this module doesn't model explicitly (camelCase keys, matching the ECS API as-is) - merged on top, wins on key conflict."
  type        = any
  default     = {}
}
