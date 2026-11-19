## Terraform Reference



### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.5 |

### Modules

No modules.

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_command"></a> [command](#input\_command) | n/a | `list(string)` | `null` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | n/a | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | n/a | `number` | `null` | no |
| <a name="input_depends_on_containers"></a> [depends\_on\_containers](#input\_depends\_on\_containers) | Startup order within the same task - not Terraform's depends\_on. | <pre>list(object({<br/>    container_name = string<br/>    condition      = string<br/>  }))</pre> | `[]` | no |
| <a name="input_docker_labels"></a> [docker\_labels](#input\_docker\_labels) | n/a | `map(string)` | `{}` | no |
| <a name="input_entrypoint"></a> [entrypoint](#input\_entrypoint) | n/a | `list(string)` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Plain environment variables. | `map(string)` | `{}` | no |
| <a name="input_essential"></a> [essential](#input\_essential) | n/a | `bool` | `true` | no |
| <a name="input_extra_fields"></a> [extra\_fields](#input\_extra\_fields) | Escape hatch for any ECS container-definition field this module doesn't model explicitly (camelCase keys, matching the ECS API as-is) - merged on top, wins on key conflict. | `any` | `{}` | no |
| <a name="input_firelens_configuration"></a> [firelens\_configuration](#input\_firelens\_configuration) | FireLens log routing (e.g. splunk/syslog router container). | <pre>object({<br/>    type    = string<br/>    options = map(string)<br/>  })</pre> | `null` | no |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | n/a | <pre>object({<br/>    command      = list(string)<br/>    interval     = optional(number, 30)<br/>    timeout      = optional(number, 5)<br/>    retries      = optional(number, 3)<br/>    start_period = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_image"></a> [image](#input\_image) | n/a | `string` | n/a | yes |
| <a name="input_linux_parameters"></a> [linux\_parameters](#input\_linux\_parameters) | n/a | <pre>object({<br/>    init_process_enabled = optional(bool)<br/>    shared_memory_size   = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_log_configuration"></a> [log\_configuration](#input\_log\_configuration) | n/a | <pre>object({<br/>    log_driver = string<br/>    options    = optional(map(string), {})<br/>    secret_options = optional(list(object({<br/>      name       = string<br/>      value_from = string<br/>    })))<br/>  })</pre> | `null` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | n/a | `number` | `null` | no |
| <a name="input_memory_reservation"></a> [memory\_reservation](#input\_memory\_reservation) | n/a | `number` | `null` | no |
| <a name="input_mount_points"></a> [mount\_points](#input\_mount\_points) | n/a | <pre>list(object({<br/>    source_volume  = string<br/>    container_path = string<br/>    read_only      = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_port_mappings"></a> [port\_mappings](#input\_port\_mappings) | n/a | <pre>list(object({<br/>    container_port = number<br/>    host_port      = optional(number)<br/>    protocol       = optional(string, "tcp")<br/>    name           = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_readonly_root_filesystem"></a> [readonly\_root\_filesystem](#input\_readonly\_root\_filesystem) | n/a | `bool` | `null` | no |
| <a name="input_repository_credentials"></a> [repository\_credentials](#input\_repository\_credentials) | ARN of a Secrets Manager secret holding the private registry credentials for pulling this image (rendered as repositoryCredentials.credentialsParameter). The task execution role needs secretsmanager:GetSecretValue on it. | `string` | `null` | no |
| <a name="input_resource_requirements"></a> [resource\_requirements](#input\_resource\_requirements) | n/a | <pre>list(object({<br/>    type  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Environment variables sourced from Secrets Manager/SSM Parameter Store - map of env var name to ARN. | `map(string)` | `{}` | no |
| <a name="input_system_controls"></a> [system\_controls](#input\_system\_controls) | n/a | <pre>list(object({<br/>    namespace = string<br/>    value     = string<br/>  }))</pre> | `[]` | no |
| <a name="input_ulimits"></a> [ulimits](#input\_ulimits) | n/a | <pre>list(object({<br/>    name       = string<br/>    soft_limit = number<br/>    hard_limit = number<br/>  }))</pre> | `[]` | no |
| <a name="input_user"></a> [user](#input\_user) | n/a | `string` | `null` | no |
| <a name="input_working_directory"></a> [working\_directory](#input\_working\_directory) | n/a | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_container_definition"></a> [container\_definition](#output\_container\_definition) | A single container definition object (camelCase keys, ECS API shape). Combine several into a list and jsonencode() for aws\_ecs\_task\_definition.container\_definitions. |
| <a name="output_json"></a> [json](#output\_json) | jsonencode() of this one container definition - not wrapped in a list. |