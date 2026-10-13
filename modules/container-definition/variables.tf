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

variable "extra_fields" {
  description = "Escape hatch for any ECS container-definition field this module doesn't model explicitly (camelCase keys, matching the ECS API as-is) - merged on top, wins on key conflict."
  type        = any
  default     = {}
}
