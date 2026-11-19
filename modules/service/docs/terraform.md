## Terraform Reference



### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_tagger"></a> [tagger](#requirement\_tagger) | >= 0.1.0 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_tagger"></a> [tagger](#module\_tagger) | rafalmasiarek/tagger/null | >= 0.7.0 |
| <a name="module_task_execution_role"></a> [task\_execution\_role](#module\_task\_execution\_role) | ../iam-role | n/a |
| <a name="module_task_role"></a> [task\_role](#module\_task\_role) | ../iam-role | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_appautoscaling_policy.alb_request_count](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.custom_metric](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_scheduled_action.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_scheduled_action) | resource |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_ecs_service.autoscaled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_service.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_security_group_rule.service_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_iam_policy_document.ecs_tasks_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| tagger_origin.self | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_target_tracking"></a> [alb\_target\_tracking](#input\_alb\_target\_tracking) | Target tracking on ALB request count. resource\_label is the target group's Application Auto Scaling resource label (<target-group-arn>/<priority>). | <pre>object({<br/>    target_value   = number<br/>    resource_label = string<br/>  })</pre> | `null` | no |
| <a name="input_auto_ingress_enabled"></a> [auto\_ingress\_enabled](#input\_auto\_ingress\_enabled) | Explicitly enable/disable the auto-ingress wiring, decoupled from cluster\_security\_group\_id's own value. On a fresh cluster the caller typically passes the SG's id straight from the resource (e.g. aws\_security\_group.this.id) before it's created - that value is unknown at plan time, and a `for_each` cannot be gated on `cluster_security_group_id != null` when the id itself is unknown (Terraform cannot determine the for\_each key set). Callers that always want this feature should pass a literal true/false here instead of relying on cluster\_security\_group\_id's nullness. Null falls back to the (unknown-unsafe) nullness check for backward compatibility with callers that pass an already-known id or omit the argument entirely. | `bool` | `null` | no |
| <a name="input_autoscaling_enabled"></a> [autoscaling\_enabled](#input\_autoscaling\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_autoscaling_max_capacity"></a> [autoscaling\_max\_capacity](#input\_autoscaling\_max\_capacity) | n/a | `number` | `2` | no |
| <a name="input_autoscaling_min_capacity"></a> [autoscaling\_min\_capacity](#input\_autoscaling\_min\_capacity) | n/a | `number` | `1` | no |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy) | n/a | <pre>list(object({<br/>    capacity_provider = string<br/>    weight            = optional(number, 1)<br/>    base              = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | n/a | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_cluster_security_group_id"></a> [cluster\_security\_group\_id](#input\_cluster\_security\_group\_id) | The cluster's task security group. When set, the module auto-discovers every container port from container\_definitions and opens an ingress rule on this SG (source: the SG itself) so the service is reachable from other cluster tasks/load balancers without manual SG wiring. | `string` | `null` | no |
| <a name="input_container_definitions"></a> [container\_definitions](#input\_container\_definitions) | List of container definition objects, e.g. from modules/container-definition's `container_definition` output - one entry per container in the task. | `any` | n/a | yes |
| <a name="input_cpu_target_tracking"></a> [cpu\_target\_tracking](#input\_cpu\_target\_tracking) | Target CPU utilization % to scale the task count around. Null disables CPU-based tracking. | `number` | `70` | no |
| <a name="input_custom_metric_target_tracking"></a> [custom\_metric\_target\_tracking](#input\_custom\_metric\_target\_tracking) | Target tracking on a CloudWatch custom metric. | <pre>object({<br/>    metric_name  = string<br/>    namespace    = string<br/>    statistic    = string<br/>    unit         = optional(string)<br/>    target_value = number<br/>    dimensions = list(object({<br/>      name  = string<br/>      value = string<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_default_ecs_infrastructure_role_arn"></a> [default\_ecs\_infrastructure\_role\_arn](#input\_default\_ecs\_infrastructure\_role\_arn) | ECS infrastructure role ARN used by managed\_ebs\_volume when it sets no role\_arn of its own. | `string` | `null` | no |
| <a name="input_default_execution_role_arn"></a> [default\_execution\_role\_arn](#input\_default\_execution\_role\_arn) | The cluster's default task execution role ARN (root module's aws\_iam\_role.task\_execution output), used when execution\_role\_arn is null. | `string` | n/a | yes |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker) | n/a | <pre>object({<br/>    enable   = bool<br/>    rollback = optional(bool, true)<br/>  })</pre> | `null` | no |
| <a name="input_deployment_controller_type"></a> [deployment\_controller\_type](#input\_deployment\_controller\_type) | "ECS" or "CODE\_DEPLOY" - null keeps the default ECS controller. | `string` | `null` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | n/a | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | n/a | `number` | `100` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | REPLICA only - defaults to 1; DAEMON services must not set it (null). | `number` | `null` | no |
| <a name="input_enable_ecs_managed_tags"></a> [enable\_ecs\_managed\_tags](#input\_enable\_ecs\_managed\_tags) | Enable ECS-managed tags: ECS auto-tags launched tasks and attached EBS volumes with cluster/service identity plus user-added task-definition/service tags. Required for cost allocation of runtime-created resources in Cost Explorer / CUR. | `bool` | `false` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | n/a | `bool` | `false` | no |
| <a name="input_enable_fault_injection"></a> [enable\_fault\_injection](#input\_enable\_fault\_injection) | n/a | `bool` | `false` | no |
| <a name="input_ephemeral_storage_gib"></a> [ephemeral\_storage\_gib](#input\_ephemeral\_storage\_gib) | n/a | `number` | `null` | no |
| <a name="input_execution_role_arn"></a> [execution\_role\_arn](#input\_execution\_role\_arn) | Falls back to default\_execution\_role\_arn when null. | `string` | `null` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | n/a | `bool` | `false` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | n/a | `number` | `null` | no |
| <a name="input_infrastructure_role_arn"></a> [infrastructure\_role\_arn](#input\_infrastructure\_role\_arn) | ARN of the ECS infrastructure role for EBS task volume management. Falls back to the cluster's default when null. | `string` | `null` | no |
| <a name="input_ipc_mode"></a> [ipc\_mode](#input\_ipc\_mode) | n/a | `string` | `null` | no |
| <a name="input_launch_type"></a> [launch\_type](#input\_launch\_type) | "FARGATE" or "EC2". Ignored (set to null) when capacity\_provider\_strategy is non-empty. | `string` | `"FARGATE"` | no |
| <a name="input_load_balancer"></a> [load\_balancer](#input\_load\_balancer) | Pure pass-through - target\_group\_arn comes from an ALB/NLB created elsewhere, never by this module. | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  }))</pre> | `[]` | no |
| <a name="input_managed_ebs_volume"></a> [managed\_ebs\_volume](#input\_managed\_ebs\_volume) | ECS-managed EBS volume per task - references a volumes entry with configure\_at\_launch = true. role\_arn is the ECS infrastructure role (AmazonECSInfrastructureRolePolicyForVolumes); falls back to default\_ecs\_infrastructure\_role\_arn. tag\_specifications tags the runtime-created volume (defaults to propagating the service's tags); the volume is created by ECS, so only AWS reserved tags, ECS managed tags (enable\_ecs\_managed\_tags) and these specifications can reach it. Provider 6.x does not expose termination\_policy. | <pre>object({<br/>    volume_name                = string<br/>    role_arn                   = optional(string)<br/>    encrypted                  = optional(bool, true)<br/>    volume_type                = optional(string)<br/>    size_in_gb                 = optional(number)<br/>    iops                       = optional(number)<br/>    throughput                 = optional(number)<br/>    snapshot_id                = optional(string)<br/>    kms_key_id                 = optional(string)<br/>    file_system_type           = optional(string)<br/>    volume_initialization_rate = optional(number)<br/>    tag_specifications = optional(list(object({<br/>      resource_type  = optional(string, "volume")<br/>      tags           = optional(map(string))<br/>      propagate_tags = optional(string)<br/>      })), [{<br/>      propagate_tags = "SERVICE"<br/>    }])<br/>  })</pre> | `null` | no |
| <a name="input_memory_target_tracking"></a> [memory\_target\_tracking](#input\_memory\_target\_tracking) | Target memory utilization % to scale the task count around. Null disables memory-based tracking. | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | n/a | yes |
| <a name="input_network_configuration"></a> [network\_configuration](#input\_network\_configuration) | Required when network\_mode = "awsvpc" (Fargate, or EC2 with awsvpc). | <pre>object({<br/>    subnets          = list(string)<br/>    security_groups  = optional(list(string), [])<br/>    assign_public_ip = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | n/a | `string` | `"awsvpc"` | no |
| <a name="input_ordered_placement_strategy"></a> [ordered\_placement\_strategy](#input\_ordered\_placement\_strategy) | n/a | <pre>list(object({<br/>    type  = string<br/>    field = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_origin_module"></a> [origin\_module](#input\_origin\_module) | Sub-module identifier stamped into the tagger:origin:module tag so resources created by different sub-modules of one origin repo can be told apart. Set per sub-module (e.g. "cluster" at root, "service", "addons", "node-group"). | `string` | `null` | no |
| <a name="input_pid_mode"></a> [pid\_mode](#input\_pid\_mode) | n/a | `string` | `null` | no |
| <a name="input_placement_constraints"></a> [placement\_constraints](#input\_placement\_constraints) | n/a | <pre>list(object({<br/>    type       = string<br/>    expression = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_propagate_tags"></a> [propagate\_tags](#input\_propagate\_tags) | Propagate tags from the service or task definition to the task: "SERVICE", "TASK\_DEFINITION" or "NONE". | `string` | `null` | no |
| <a name="input_proxy_configuration"></a> [proxy\_configuration](#input\_proxy\_configuration) | Task-level sidecar proxy (e.g. App Mesh). properties are opaque key/value pairs. | <pre>object({<br/>    type           = string<br/>    container_name = string<br/>    properties     = optional(map(string), {})<br/>  })</pre> | `null` | no |
| <a name="input_requires_compatibilities"></a> [requires\_compatibilities](#input\_requires\_compatibilities) | Launch types the task definition is compatible with. Must match launch\_type or capacity\_provider\_strategy. Defaults to ["FARGATE"] but should be set explicitly when using EC2. | `list(string)` | <pre>[<br/>  "FARGATE"<br/>]</pre> | no |
| <a name="input_runtime_platform"></a> [runtime\_platform](#input\_runtime\_platform) | n/a | <pre>object({<br/>    cpu_architecture        = optional(string)<br/>    operating_system_family = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_scale_in_cooldown_seconds"></a> [scale\_in\_cooldown\_seconds](#input\_scale\_in\_cooldown\_seconds) | n/a | `number` | `300` | no |
| <a name="input_scale_out_cooldown_seconds"></a> [scale\_out\_cooldown\_seconds](#input\_scale\_out\_cooldown\_seconds) | n/a | `number` | `60` | no |
| <a name="input_scheduled_actions"></a> [scheduled\_actions](#input\_scheduled\_actions) | Application Auto Scaling scheduled actions (require autoscaling\_enabled). Names must be unique per target. | <pre>list(object({<br/>    name         = string<br/>    schedule     = string<br/>    timezone     = optional(string)<br/>    min_capacity = number<br/>    max_capacity = number<br/>  }))</pre> | `[]` | no |
| <a name="input_scheduling_strategy"></a> [scheduling\_strategy](#input\_scheduling\_strategy) | "REPLICA" or "DAEMON". DAEMON deploys one task per eligible EC2 container instance: EC2 capacity only, no desired\_count, no service autoscaling, no ordered placement strategy, deployment percentages pinned to 100/0. | `string` | `"REPLICA"` | no |
| <a name="input_service_connect"></a> [service\_connect](#input\_service\_connect) | ECS Service Connect configuration - requires network\_mode = "awsvpc" (Fargate) or "bridge" (EC2). | <pre>object({<br/>    namespace = string<br/>    enabled   = optional(bool, true)<br/>    service = optional(list(object({<br/>      discovery_name        = string<br/>      port_name             = optional(string)<br/>      ingress_port_override = optional(number)<br/>      client_alias = optional(list(object({<br/>        dns_name = string<br/>        port     = number<br/>      })), [])<br/>    })), [])<br/>  })</pre> | `null` | no |
| <a name="input_service_registries"></a> [service\_registries](#input\_service\_registries) | Cloud Map service discovery registration. | <pre>list(object({<br/>    registry_arn   = string<br/>    port           = optional(number)<br/>    container_name = optional(string)<br/>    container_port = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_tagger_additional_services"></a> [tagger\_additional\_services](#input\_tagger\_additional\_services) | Extra terraform-null-tagger `service` data per taggable resource, keyed by the same key as local.taggable (e.g. "subnet-public-a"). Merged on top of what this module computes automatically - lets a caller tag something this module doesn't know about, without waiting for a new module release. | `any` | `{}` | no |
| <a name="input_tagger_context"></a> [tagger\_context](#input\_tagger\_context) | module.tagger.context from the root stack's base terraform-null-tagger call. | `any` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Custom tags for the resource(s). | `map(string)` | `{}` | no |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | n/a | `number` | `null` | no |
| <a name="input_task_execution_role"></a> [task\_execution\_role](#input\_task\_execution\_role) | Create-or-use task execution role, overriding execution\_role\_arn / default\_execution\_role\_arn. At most one of arn / create. | <pre>object({<br/>    arn = optional(string)<br/>    create = optional(object({<br/>      name                    = optional(string)<br/>      permission_boundary_arn = optional(string)<br/>      managed_policy_arns     = optional(list(string), [])<br/>      inline_policies = optional(map(list(object({<br/>        sid       = optional(string)<br/>        effect    = string<br/>        actions   = list(string)<br/>        resources = list(string)<br/>      }))), {})<br/>      least_privilege = optional(object({<br/>        ecr_registry_arns          = optional(list(string), [])<br/>        secretsmanager_secret_arns = optional(list(string), [])<br/>        ssm_parameter_arns         = optional(list(string), [])<br/>        kms_key_arns               = optional(list(string), [])<br/>        route53_hosted_zone_arns   = optional(list(string), [])<br/>        }), {<br/>        ecr_registry_arns          = []<br/>        secretsmanager_secret_arns = []<br/>        ssm_parameter_arns         = []<br/>        kms_key_arns               = []<br/>        route53_hosted_zone_arns   = []<br/>      })<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | n/a | `number` | `null` | no |
| <a name="input_task_role"></a> [task\_role](#input\_task\_role) | Create-or-use task role, overriding task\_role\_arn. At most one of arn / create. | <pre>object({<br/>    arn = optional(string)<br/>    create = optional(object({<br/>      name                    = optional(string)<br/>      permission_boundary_arn = optional(string)<br/>      managed_policy_arns     = optional(list(string), [])<br/>      inline_policies = optional(map(list(object({<br/>        sid       = optional(string)<br/>        effect    = string<br/>        actions   = list(string)<br/>        resources = list(string)<br/>      }))), {})<br/>      least_privilege = optional(object({<br/>        ecr_registry_arns          = optional(list(string), [])<br/>        secretsmanager_secret_arns = optional(list(string), [])<br/>        ssm_parameter_arns         = optional(list(string), [])<br/>        kms_key_arns               = optional(list(string), [])<br/>        route53_hosted_zone_arns   = optional(list(string), [])<br/>        }), {<br/>        ecr_registry_arns          = []<br/>        secretsmanager_secret_arns = []<br/>        ssm_parameter_arns         = []<br/>        kms_key_arns               = []<br/>        route53_hosted_zone_arns   = []<br/>      })<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | n/a | `string` | `null` | no |
| <a name="input_use_tagger"></a> [use\_tagger](#input\_use\_tagger) | Compute and apply standardized tags via terraform-null-tagger. When false, use var.tags as-is instead. | `bool` | `true` | no |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | List of volume configurations. Each entry: { name, host\_path?, configure\_at\_launch?, efs\_volume\_configuration?, ebs\_volume\_configuration? }. EBS volumes require infrastructure\_role\_arn (or the cluster's default) for ECS to manage the volume lifecycle. | `any` | `[]` | no |
| <a name="input_wait_for_steady_state"></a> [wait\_for\_steady\_state](#input\_wait\_for\_steady\_state) | n/a | `bool` | `false` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_service_id"></a> [service\_id](#output\_service\_id) | n/a |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | n/a |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | n/a |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | n/a |
| <a name="output_task_execution_role_arn"></a> [task\_execution\_role\_arn](#output\_task\_execution\_role\_arn) | n/a |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | n/a |