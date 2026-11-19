## Terraform Reference



### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_tagger"></a> [tagger](#requirement\_tagger) | >= 0.1.0 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_instance_role"></a> [instance\_role](#module\_instance\_role) | ../iam-role | n/a |
| <a name="module_nodes"></a> [nodes](#module\_nodes) | rafalmasiarek/ec2-autoscale-group/aws | 0.2.1 |
| <a name="module_tagger"></a> [tagger](#module\_tagger) | rafalmasiarek/tagger/null | >= 0.7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_instance_profile.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_ec2_instance_type.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type) | data source |
| [aws_iam_policy_document.instance_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ssm_parameter.ami_arm64](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.ami_x86_64](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| tagger_origin.self | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | Explicit AMI (e.g. a Marketplace/custom image). Falls back to the official AL2023 ECS-optimized AMI via SSM, arch-matched to instance\_type, when null. | `string` | `null` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | n/a | `bool` | `false` | no |
| <a name="input_autoscaling_policies_enabled"></a> [autoscaling\_policies\_enabled](#input\_autoscaling\_policies\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_block_device_mappings"></a> [block\_device\_mappings](#input\_block\_device\_mappings) | n/a | `any` | `[]` | no |
| <a name="input_cloudinit_config"></a> [cloudinit\_config](#input\_cloudinit\_config) | Wildcard passthrough to every input of terraform-aws-ec2-cloudinit (cloud\_config, packages, users, files, mounts, ansible\_pull, artifacts, ansible\_playbooks, ...), merged with this module's own mandatory ECS agent bootstrap script - the bootstrap script always runs last, after any cloudinit\_parts set here, to guarantee the node actually joins the cluster regardless of what comes before it. | `any` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | ECS cluster this node group joins (used to build the ECS agent's user\_data). | `string` | n/a | yes |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | n/a | `number` | `null` | no |
| <a name="input_ecs_agent_config"></a> [ecs\_agent\_config](#input\_ecs\_agent\_config) | ECS Container Agent configuration appended to /etc/ecs/ecs.config at first boot - generic environment passthrough plus structurally built registry auth; a first-boot systemd unit then enables and starts the packaged ecs unit. See docs/rfc-ecs-agent-registry-auth.md. | <pre>object({<br/>    environment = optional(map(string), {})<br/>    registry_auth = optional(object({<br/>      type = string<br/>      registries = map(object({<br/>        username = string<br/>        password = object({<br/>          plaintext                 = optional(string)<br/>          file                      = optional(string)<br/>          secretsmanager_secret_arn = optional(string)<br/>          kms_key_arn               = optional(string)<br/>        })<br/>        email = optional(string)<br/>      }))<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_force_delete"></a> [force\_delete](#input\_force\_delete) | Destroy the ASG without waiting for instances to terminate (skips graceful drain). Useful for fast teardown of disposable environments. | `bool` | `false` | no |
| <a name="input_iam"></a> [iam](#input\_iam) | Create-or-use for this node group's instance role + profile, overriding the shared root role. Omit to keep the shared role. | <pre>object({<br/>    use_existing = optional(object({<br/>      instance_profile_name = string<br/>    }))<br/>    create = optional(object({<br/>      name                    = optional(string)<br/>      permission_boundary_arn = optional(string)<br/>      managed_policy_arns     = optional(list(string), [])<br/>      inline_policies = optional(map(list(object({<br/>        sid       = optional(string)<br/>        effect    = string<br/>        actions   = list(string)<br/>        resources = list(string)<br/>      }))), {})<br/>      least_privilege = optional(object({<br/>        ecr_registry_arns          = optional(list(string), [])<br/>        secretsmanager_secret_arns = optional(list(string), [])<br/>        ssm_parameter_arns         = optional(list(string), [])<br/>        kms_key_arns               = optional(list(string), [])<br/>        route53_hosted_zone_arns   = optional(list(string), [])<br/>        }), {<br/>        ecr_registry_arns          = []<br/>        secretsmanager_secret_arns = []<br/>        ssm_parameter_arns         = []<br/>        kms_key_arns               = []<br/>        route53_hosted_zone_arns   = []<br/>      })<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#input\_iam\_instance\_profile\_name) | n/a | `string` | n/a | yes |
| <a name="input_instance_refresh"></a> [instance\_refresh](#input\_instance\_refresh) | n/a | `any` | <pre>{<br/>  "preferences": {<br/>    "min_healthy_percentage": 66<br/>  },<br/>  "strategy": "Rolling"<br/>}</pre> | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | n/a | `string` | n/a | yes |
| <a name="input_key_name"></a> [key\_name](#input\_key\_name) | n/a | `string` | `null` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | n/a | `number` | n/a | yes |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | n/a | `number` | n/a | yes |
| <a name="input_mixed_instances_policy"></a> [mixed\_instances\_policy](#input\_mixed\_instances\_policy) | n/a | `any` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Node group name - becomes the ASG + launch template name. | `string` | n/a | yes |
| <a name="input_origin_module"></a> [origin\_module](#input\_origin\_module) | Sub-module identifier stamped into the tagger:origin:module tag so resources created by different sub-modules of one origin repo can be told apart. Set per sub-module (e.g. "cluster" at root, "service", "addons", "node-group"). | `string` | `null` | no |
| <a name="input_protect_from_scale_in"></a> [protect\_from\_scale\_in](#input\_protect\_from\_scale\_in) | ASG ProtectFromScaleIn flag for the nodes. True (default) is required for ECS managed termination protection to work (the agent drains tasks and deregisters the container instance before shutdown). While every instance is protected, ASG cannot scale in on its own - set false to allow ASG-initiated scale-in. | `bool` | `true` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_tagger_additional_services"></a> [tagger\_additional\_services](#input\_tagger\_additional\_services) | Extra terraform-null-tagger `service` data per taggable resource, keyed by the same key as local.taggable (e.g. "subnet-public-a"). Merged on top of what this module computes automatically - lets a caller tag something this module doesn't know about, without waiting for a new module release. | `any` | `{}` | no |
| <a name="input_tagger_context"></a> [tagger\_context](#input\_tagger\_context) | module.tagger.context from the root stack's base terraform-null-tagger call. | `any` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Custom tags for the resource(s). | `map(string)` | `{}` | no |
| <a name="input_use_tagger"></a> [use\_tagger](#input\_use\_tagger) | Compute and apply standardized tags via terraform-null-tagger. When false, use var.tags as-is instead. | `bool` | `true` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | n/a | `list(string)` | n/a | yes |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agent_config_script"></a> [agent\_config\_script](#output\_agent\_config\_script) | n/a |
| <a name="output_agent_start_unit"></a> [agent\_start\_unit](#output\_agent\_start\_unit) | n/a |
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn) | n/a |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | n/a |
| <a name="output_instance_profile_name"></a> [instance\_profile\_name](#output\_instance\_profile\_name) | n/a |