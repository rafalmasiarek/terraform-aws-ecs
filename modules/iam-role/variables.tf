variable "name" {
  description = "Role name - null lets AWS generate one."
  type        = string
  default     = null
}

variable "assume_role_policy_document" {
  description = "Assume-role policy document JSON, e.g. from aws_iam_policy_document."
  type        = string
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}

variable "managed_policy_arns" {
  description = "AWS-managed and custom managed policies to attach - the caller includes the base policies."
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Policy name => statements; each entry becomes one inline role policy."
  type = map(list(object({
    sid       = optional(string)
    effect    = string
    actions   = list(string)
    resources = list(string)
  })))
  default = {}

  validation {
    condition = can(element([for _ in [1] : 1 if alltrue([
      for statements in values(var.inline_policies) : alltrue([
        for s in statements : s.effect != "" && length(s.actions) > 0 && length(s.resources) > 0
      ])
    ])], 0))
    error_message = "Every inline policy statement needs a non-empty effect, actions and resources."
  }
}

variable "least_privilege" {
  description = "Scoped ARN lists rendered into one inline least-privilege policy."
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

variable "tags" {
  type    = map(string)
  default = {}
}
