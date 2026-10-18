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
