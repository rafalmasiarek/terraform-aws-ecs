## Terraform Reference



### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_least_privilege"></a> [least\_privilege](#module\_least\_privilege) | ../iam-policy-documents | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.least_privilege](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_assume_role_policy_document"></a> [assume\_role\_policy\_document](#input\_assume\_role\_policy\_document) | Assume-role policy document JSON, e.g. from aws\_iam\_policy\_document. | `string` | n/a | yes |
| <a name="input_inline_policies"></a> [inline\_policies](#input\_inline\_policies) | Policy name => statements; each entry becomes one inline role policy. | <pre>map(list(object({<br/>    sid       = optional(string)<br/>    effect    = string<br/>    actions   = list(string)<br/>    resources = list(string)<br/>  })))</pre> | `{}` | no |
| <a name="input_least_privilege"></a> [least\_privilege](#input\_least\_privilege) | Scoped ARN lists rendered into one inline least-privilege policy. | <pre>object({<br/>    ecr_registry_arns          = optional(list(string), [])<br/>    secretsmanager_secret_arns = optional(list(string), [])<br/>    ssm_parameter_arns         = optional(list(string), [])<br/>    kms_key_arns               = optional(list(string), [])<br/>    route53_hosted_zone_arns   = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "ecr_registry_arns": [],<br/>  "kms_key_arns": [],<br/>  "route53_hosted_zone_arns": [],<br/>  "secretsmanager_secret_arns": [],<br/>  "ssm_parameter_arns": []<br/>}</pre> | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | AWS-managed and custom managed policies to attach - the caller includes the base policies. | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Role name - null lets AWS generate one. | `string` | `null` | no |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | n/a | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | n/a |
| <a name="output_name"></a> [name](#output\_name) | n/a |