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
| [aws_ecs_account_setting_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_account_setting_default) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_settings"></a> [settings](#input\_settings) | ECS account default settings (name => value). Account-wide and per-Region - this is an explicit opt-in. Writable names: containerInsights, awsvpcTrunking, defaultLogDriverMode, dualStackIPv6, fargateFIPSMode, fargateTaskRetirementWaitPeriod, fargateEventWindows. Excluded as immutable or AWS-managed: serviceLongArnFormat / taskLongArnFormat / containerInstanceLongArnFormat (long-ARN opt-out closed 2021-04-01), tagResourceAuthorization (no longer disableable since 2024-03-07), guardDutyActivate (read-only, controlled by GuardDuty). | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_setting_names"></a> [setting\_names](#output\_setting\_names) | n/a |