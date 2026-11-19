## Terraform Reference



### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_cwquery"></a> [cwquery](#requirement\_cwquery) | >= 0.1.0 |
| <a name="requirement_tagger"></a> [tagger](#requirement\_tagger) | >= 0.1.0 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_addon_log_group"></a> [addon\_log\_group](#module\_addon\_log\_group) | rafalmasiarek/cloudwatch/aws//modules/log-group | >= 0.1.0 |
| <a name="module_blackbox_exporter_service"></a> [blackbox\_exporter\_service](#module\_blackbox\_exporter\_service) | ../service | n/a |
| <a name="module_cadvisor_service"></a> [cadvisor\_service](#module\_cadvisor\_service) | ../service | n/a |
| <a name="module_cloudwatch_agent_service"></a> [cloudwatch\_agent\_service](#module\_cloudwatch\_agent\_service) | ../service | n/a |
| <a name="module_falco_service"></a> [falco\_service](#module\_falco\_service) | ../service | n/a |
| <a name="module_node_cpu_high"></a> [node\_cpu\_high](#module\_node\_cpu\_high) | rafalmasiarek/cloudwatch/aws//modules/metric-alarm | >= 0.1.0 |
| <a name="module_node_exporter_service"></a> [node\_exporter\_service](#module\_node\_exporter\_service) | ../service | n/a |
| <a name="module_node_memory_high"></a> [node\_memory\_high](#module\_node\_memory\_high) | rafalmasiarek/cloudwatch/aws//modules/metric-alarm | >= 0.1.0 |
| <a name="module_opentelemetry_service"></a> [opentelemetry\_service](#module\_opentelemetry\_service) | ../service | n/a |
| <a name="module_service_tasks_zero"></a> [service\_tasks\_zero](#module\_service\_tasks\_zero) | rafalmasiarek/cloudwatch/aws//modules/metric-alarm | >= 0.1.0 |
| <a name="module_tagger"></a> [tagger](#module\_tagger) | rafalmasiarek/tagger/null | >= 0.7.0 |
| <a name="module_traefik_service"></a> [traefik\_service](#module\_traefik\_service) | ../service | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_dashboard.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_event_rule.asg_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.ecs_deployments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.asg_scaling_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.ecs_deployments_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution_awslogs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.traefik_acme_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.traefik_execution_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb.traefik](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.traefik](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.traefik](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group_rule.traefik_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_ssm_parameter.traefik_routes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.addon_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route_table.vpc_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_table) | data source |
| [aws_route_tables.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |
| [aws_subnets.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| tagger_origin.self | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloudwatch_log_group_retention_in_days"></a> [cloudwatch\_log\_group\_retention\_in\_days](#input\_cloudwatch\_log\_group\_retention\_in\_days) | Retention for every addon task's CloudWatch log group. | `number` | `30` | no |
| <a name="input_cluster_addons"></a> [cluster\_addons](#input\_cluster\_addons) | ECS cluster infrastructure add-ons: traefik, opentelemetry, cloudwatch\_agent, node\_exporter, cadvisor, falco, blackbox\_exporter. See docs/addons.md for per-preset semantics. | `any` | `null` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ECS cluster identifier (short name or full ARN). | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | ECS cluster short name (used for resource naming). | `string` | n/a | yes |
| <a name="input_cluster_security_group_id"></a> [cluster\_security\_group\_id](#input\_cluster\_security\_group\_id) | Cluster security group ID. Task ENIs (awsvpc) and node host ports (bridge) join this SG. | `string` | `null` | no |
| <a name="input_default_execution_role_arn"></a> [default\_execution\_role\_arn](#input\_default\_execution\_role\_arn) | The cluster's default task execution role ARN, used when a preset doesn't need its own execution role. | `string` | `null` | no |
| <a name="input_infrastructure_role_arn"></a> [infrastructure\_role\_arn](#input\_infrastructure\_role\_arn) | ARN of the ECS infrastructure role for EBS task volume management. Required when any addon uses configure\_at\_launch volumes. | `string` | `null` | no |
| <a name="input_origin_module"></a> [origin\_module](#input\_origin\_module) | Sub-module identifier stamped into the tagger:origin:module tag so resources created by different sub-modules of one origin repo can be told apart. Set per sub-module (e.g. "cluster" at root, "service", "addons", "node-group"). | `string` | `null` | no |
| <a name="input_plan_facts"></a> [plan\_facts](#input\_plan\_facts) | Caller-computed plan-critical facts (see root addons.tf). | `any` | `{}` | no |
| <a name="input_tagger_additional_services"></a> [tagger\_additional\_services](#input\_tagger\_additional\_services) | Extra terraform-null-tagger `service` data per taggable resource, keyed by the same key as local.taggable (e.g. "subnet-public-a"). Merged on top of what this module computes automatically - lets a caller tag something this module doesn't know about, without waiting for a new module release. | `any` | `{}` | no |
| <a name="input_tagger_context"></a> [tagger\_context](#input\_tagger\_context) | module.tagger.context from the root stack's base terraform-null-tagger call. | `any` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Custom tags for the resource(s). | `map(string)` | `{}` | no |
| <a name="input_use_tagger"></a> [use\_tagger](#input\_use\_tagger) | Compute and apply standardized tags via terraform-null-tagger. When false, use var.tags as-is instead. | `bool` | `true` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID. Required when any preset creates a load balancer or needs VPC-scoped SG rules. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_blackbox_exporter"></a> [blackbox\_exporter](#output\_blackbox\_exporter) | Blackbox exporter outputs (null when disabled). |
| <a name="output_cadvisor"></a> [cadvisor](#output\_cadvisor) | cAdvisor outputs (null when disabled). |
| <a name="output_cloudwatch_agent"></a> [cloudwatch\_agent](#output\_cloudwatch\_agent) | CloudWatch agent outputs (null when disabled). |
| <a name="output_falco"></a> [falco](#output\_falco) | Falco outputs (null when disabled). |
| <a name="output_node_exporter"></a> [node\_exporter](#output\_node\_exporter) | Node exporter outputs (null when disabled). |
| <a name="output_observability"></a> [observability](#output\_observability) | Observability addon outputs (null when disabled). |
| <a name="output_opentelemetry"></a> [opentelemetry](#output\_opentelemetry) | OpenTelemetry collector outputs (null when disabled). |
| <a name="output_traefik"></a> [traefik](#output\_traefik) | Traefik add-on outputs (null when the preset is disabled). |