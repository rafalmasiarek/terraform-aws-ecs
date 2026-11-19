## Terraform Reference



### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

### Modules

No modules.

### Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_least_privilege"></a> [least\_privilege](#input\_least\_privilege) | Scoped ARN lists rendered into one inline least-privilege policy. | <pre>object({<br/>    ecr_registry_arns          = optional(list(string), [])<br/>    secretsmanager_secret_arns = optional(list(string), [])<br/>    ssm_parameter_arns         = optional(list(string), [])<br/>    kms_key_arns               = optional(list(string), [])<br/>    route53_hosted_zone_arns   = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "ecr_registry_arns": [],<br/>  "kms_key_arns": [],<br/>  "route53_hosted_zone_arns": [],<br/>  "secretsmanager_secret_arns": [],<br/>  "ssm_parameter_arns": []<br/>}</pre> | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_json"></a> [json](#output\_json) | n/a |