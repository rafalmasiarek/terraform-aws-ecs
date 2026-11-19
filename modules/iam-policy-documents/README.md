# terraform-aws-ecs/modules/iam-policy-documents
![](https://raw.githubusercontent.com/rafalmasiarek/readme-gen/main/banners/.gitkeep)

## About

Builds an IAM policy JSON document (least-privilege ECR/execution
permissions) - a pure `data "aws_iam_policy_document"` wrapper, no
resources created. Called internally by the root
[terraform-aws-ecs](../../) module's task execution role setup - not
meant to be called standalone.



## License
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

```text
The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files, to deal in the Software
without restriction.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

Source: https://opensource.org/licenses/MIT
```
See [LICENSE](LICENSE) for full details.
## Authors

- Rafał Masiarek | [website](https://masiarek.pl) | [email](mailto:rafal@masiarek.pl) | [github](https://github.com/rafalmasiarek)


## Cluster add-ons

`cluster_addons` enables pre-built infrastructure services on the cluster:

| Preset | What it runs |
|---|---|
| `traefik` | Traefik ingress controller (load balancer type service). |
| `opentelemetry` | OTel Collector (host network, EC2). |
| `cloudwatch_agent` | CloudWatch Agent (EC2, privileged). |
| `node_exporter` | Prometheus node exporter (EC2, host metrics). |
| `cadvisor` | cAdvisor container metrics (EC2, privileged). |
| `falco` | Falco runtime security (EC2, privileged). |
| `blackbox_exporter` | Blackbox prober (Fargate or EC2). |
| `observability` | Composite: opentelemetry + node_exporter + cadvisor + blackbox_exporter. |

Each preset is independent; enable only what you need. Per-preset configuration (image, port, env, scaling) is documented in `docs/addons.md`.

```hcl
module "ecs" {
  source = "rafalmasiarek/aws-ecs"

  # ...

  cluster_addons = {
    observability = {}
    traefik       = {}
  }
}
```

Output: `addons` — per-preset outputs (service ARN, task definition family, LB DNS where applicable). Null when `cluster_addons` is unset.


## Tagger integration

All resources are tagged via terraform-null-tagger when `use_tagger = true`. Each sub-module (`node-group`, `service`, `iam-role`, `addons`) copies the same `tagger.tf` wiring and computes its own tags from the shared `tagger_context`:

- `container.cluster` — cluster name
- `container.task_family` — per service
- `container.node_group` — per node group
- `block_storage` — EBS volumes (type, file_system_type; size/iops excluded due to live resize drift)
- `compute` — node group instances (instance_type, os, architecture)
- `origin_module` — sub-module path (e.g. `github.com/rafalmasiarek/terraform-aws-ecs//modules/service`)


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
| <a name="module_account_settings"></a> [account\_settings](#module\_account\_settings) | ./modules/account-settings | n/a |
| <a name="module_addons"></a> [addons](#module\_addons) | ./modules/addons | n/a |
| <a name="module_instance_least_privilege"></a> [instance\_least\_privilege](#module\_instance\_least\_privilege) | ./modules/iam-policy-documents | n/a |
| <a name="module_log_group"></a> [log\_group](#module\_log\_group) | rafalmasiarek/cloudwatch/aws//modules/log-group | >= 0.1.0 |
| <a name="module_node_group"></a> [node\_group](#module\_node\_group) | ./modules/node-group | n/a |
| <a name="module_service"></a> [service](#module\_service) | ./modules/service | n/a |
| <a name="module_tagger"></a> [tagger](#module\_tagger) | rafalmasiarek/tagger/null | >= 0.7.0 |
| <a name="module_task_execution_least_privilege"></a> [task\_execution\_least\_privilege](#module\_task\_execution\_least\_privilege) | ./modules/iam-policy-documents | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_ecs_capacity_provider.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_iam_instance_profile.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ecs_infrastructure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.instance_awslogs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.instance_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.instance_least_privilege](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_execution_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_execution_least_privilege](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ecs_infrastructure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_key.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_ephemeral_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_health_check_port](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_vpc_security_group_egress_rule.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.service_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ec2_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_infrastructure_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_tasks_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.exec_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.instance_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task_execution_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| tagger_origin.self | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_settings"></a> [account\_settings](#input\_account\_settings) | ECS account default settings (name => value) - account-wide and per-Region, explicit opt-in. See modules/account-settings for the writable names and allowed values. | `map(string)` | `{}` | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | Security group of an existing ALB/NLB, if any - opens the ephemeral port range (32768-61000) from it to the cluster's own SG. This module never creates the load balancer itself. | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_kms_key_id"></a> [cloudwatch\_log\_group\_kms\_key\_id](#input\_cloudwatch\_log\_group\_kms\_key\_id) | KMS key ID for encrypting the execute-command CloudWatch log group. | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#input\_cloudwatch\_log\_group\_name) | Use an existing CloudWatch log group for execute-command logging instead of the module-created one (create\_cloudwatch\_log\_group must be false). | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_retention_in_days"></a> [cloudwatch\_log\_group\_retention\_in\_days](#input\_cloudwatch\_log\_group\_retention\_in\_days) | n/a | `number` | `30` | no |
| <a name="input_cluster_addons"></a> [cluster\_addons](#input\_cluster\_addons) | ECS cluster infrastructure add-ons: traefik, opentelemetry, cloudwatch\_agent, node\_exporter, cadvisor, falco, blackbox\_exporter. Omit (null) to disable all. See docs/addons.md and modules/addons/variables.tf for the full schema and per-preset semantics. | `any` | `null` | no |
| <a name="input_container_insights"></a> [container\_insights](#input\_container\_insights) | Cluster-level Container Insights: "disabled", "enabled" or "enhanced". Null keeps the account default. | `string` | `null` | no |
| <a name="input_create_cloudwatch_log_group"></a> [create\_cloudwatch\_log\_group](#input\_create\_cloudwatch\_log\_group) | Create a CloudWatch log group for cluster-level execute-command logging. | `bool` | `false` | no |
| <a name="input_create_ecs_infrastructure_role"></a> [create\_ecs\_infrastructure\_role](#input\_create\_ecs\_infrastructure\_role) | Create the ECS infrastructure role (AmazonECSInfrastructureRolePolicyForVolumes) - the default role\_arn for services' managed\_ebs\_volume entries. Ignored when infrastructure\_role\_arn is set. | `bool` | `false` | no |
| <a name="input_create_instance_iam_role"></a> [create\_instance\_iam\_role](#input\_create\_instance\_iam\_role) | Create the shared IAM role/instance profile EC2 node groups attach to (AmazonEC2ContainerServiceforEC2Role + AmazonSSMManagedInstanceCore). Set false and pass iam\_instance\_profile\_name per node group yourself if you already manage this elsewhere. | `bool` | `true` | no |
| <a name="input_create_task_execution_role"></a> [create\_task\_execution\_role](#input\_create\_task\_execution\_role) | Create a default ECS task execution role (AmazonECSTaskExecutionRolePolicy) that modules/service falls back to when a task doesn't specify its own execution\_role\_arn. | `bool` | `true` | no |
| <a name="input_default_capacity_provider_strategy"></a> [default\_capacity\_provider\_strategy](#input\_default\_capacity\_provider\_strategy) | Cluster default capacity provider strategy - fallback for services that don't set their own. capacity\_provider must be enabled on the cluster (a node-group capacity provider name or an fargate\_capacity\_providers entry). | <pre>list(object({<br/>    capacity_provider = string<br/>    weight            = optional(number, 1)<br/>    base              = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_exec_command_s3"></a> [exec\_command\_s3](#input\_exec\_command\_s3) | ECS Exec logging to S3, in addition to or instead of CloudWatch Logs. Bucket and KMS key are create-or-use; when created they get a least-privilege key policy and SSE-KMS. | <pre>object({<br/>    bucket = object({<br/>      create     = optional(bool, true)<br/>      name       = optional(string)<br/>      key_prefix = optional(string)<br/>    })<br/>    kms = optional(object({<br/>      create = optional(bool, true)<br/>      key_id = optional(string)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_fargate_capacity_providers"></a> [fargate\_capacity\_providers](#input\_fargate\_capacity\_providers) | Subset of ["FARGATE", "FARGATE\_SPOT"] to enable on this cluster. AWS-managed - no resources created for these. | `list(string)` | `[]` | no |
| <a name="input_infrastructure_role_arn"></a> [infrastructure\_role\_arn](#input\_infrastructure\_role\_arn) | ARN of an existing ECS infrastructure role to use for EBS task volumes instead of creating one. When set, create\_ecs\_infrastructure\_role is ignored. | `string` | `null` | no |
| <a name="input_instance_role_inline_policies"></a> [instance\_role\_inline\_policies](#input\_instance\_role\_inline\_policies) | Policy name => statements; each entry becomes one inline policy on the shared instance role. | <pre>map(list(object({<br/>    sid       = optional(string)<br/>    effect    = string<br/>    actions   = list(string)<br/>    resources = list(string)<br/>  })))</pre> | `{}` | no |
| <a name="input_instance_role_least_privilege"></a> [instance\_role\_least\_privilege](#input\_instance\_role\_least\_privilege) | Scoped ARN lists for the shared instance role. Node groups using the shared profile auto-add their registry\_auth Secrets Manager and KMS ARNs on top. | <pre>object({<br/>    ecr_registry_arns          = optional(list(string), [])<br/>    secretsmanager_secret_arns = optional(list(string), [])<br/>    ssm_parameter_arns         = optional(list(string), [])<br/>    kms_key_arns               = optional(list(string), [])<br/>    route53_hosted_zone_arns   = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "ecr_registry_arns": [],<br/>  "kms_key_arns": [],<br/>  "route53_hosted_zone_arns": [],<br/>  "secretsmanager_secret_arns": [],<br/>  "ssm_parameter_arns": []<br/>}</pre> | no |
| <a name="input_instance_role_managed_policy_arns"></a> [instance\_role\_managed\_policy\_arns](#input\_instance\_role\_managed\_policy\_arns) | Extra managed policies for the shared instance role, on top of the base ECS + SSM policies. | `list(string)` | `[]` | no |
| <a name="input_instance_role_permission_boundary_arn"></a> [instance\_role\_permission\_boundary\_arn](#input\_instance\_role\_permission\_boundary\_arn) | n/a | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | ECS cluster name. | `string` | n/a | yes |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | EC2-backed capacity providers. Each entry creates one terraform-aws-ec2-autoscale-group instance (modules/node-group) plus one ECS capacity provider wired to it. See modules/node-group/variables.tf for the full per-entry shape - every field there is a key in this entry's object. | `any` | `{}` | no |
| <a name="input_origin_module"></a> [origin\_module](#input\_origin\_module) | Sub-module identifier stamped into the tagger:origin:module tag so resources created by different sub-modules of one origin repo can be told apart. Set per sub-module (e.g. "cluster" at root, "service", "addons", "node-group"). | `string` | `null` | no |
| <a name="input_services"></a> [services](#input\_services) | One ECS service + task definition per entry. See modules/service/variables.tf for the full per-entry shape - every field there is a key in this entry's object. container\_definitions is typically built by calling this repo's modules/container-definition submodule once per container, outside this module. Root-level extras: open\_task\_ports = { source\_cidr\_ipv4?, source\_cidr\_ipv6?, source\_security\_group\_id? } auto-opens the entry's container port mappings (bridge: hostPort, awsvpc/Fargate: containerPort) on the cluster's task SG, tagged with the service identity - opt-in per entry, omitted = no ingress rules. source\_security\_group\_id models an ALB/NLB or any other internal ingress SG; source\_cidr\_ipv4/ipv6 model a plain CIDR source. At least one of the three is required when open\_task\_ports is set. In awsvpc mode, a portMappings entry with containerPort = null gets a stable port auto-assigned from 20000-60000 (derived from the service/container/mapping address, not re-randomized between applies) instead of requiring the caller to pick one and risk colliding with another service's guess - the resolved value is also injected as env var PORT\_<index> for the container's own command to bind to. A container with more than one portMapping (either network mode) gets a traefik.<http\|tcp\|udp>.services.<name>.loadbalancer.server.port dockerLabel per port, keyed on containerPort. Give the portMapping its own name (ECS's Service Connect field) and that becomes the traefik service name verbatim - write the same word in cluster\_addons.traefik's routes/tcp\_routes/udp\_routes service field (the module appends @ecs itself), nothing to reconstruct. An unnamed port falls back to <service-key>-<container-name>-<index>, unique by construction but only referenceable if you know the formula. A container named as the service target of any cluster\_addons.traefik route/tcp\_route/udp\_route also gets traefik.enable="true" automatically - the traefik addon's ECS provider runs with exposedByDefault=false, so this would otherwise be required by hand. | `any` | `{}` | no |
| <a name="input_tagger_additional_services"></a> [tagger\_additional\_services](#input\_tagger\_additional\_services) | Extra terraform-null-tagger `service` data per taggable resource, keyed by the same key as local.taggable (e.g. "subnet-public-a"). Merged on top of what this module computes automatically - lets a caller tag something this module doesn't know about, without waiting for a new module release. | `any` | `{}` | no |
| <a name="input_tagger_context"></a> [tagger\_context](#input\_tagger\_context) | module.tagger.context from the root stack's base terraform-null-tagger call. | `any` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Custom tags for the resource(s). | `map(string)` | `{}` | no |
| <a name="input_task_execution_role_inline_policies"></a> [task\_execution\_role\_inline\_policies](#input\_task\_execution\_role\_inline\_policies) | Policy name => statements; each entry becomes one inline policy on the shared task execution role. | <pre>map(list(object({<br/>    sid       = optional(string)<br/>    effect    = string<br/>    actions   = list(string)<br/>    resources = list(string)<br/>  })))</pre> | `{}` | no |
| <a name="input_task_execution_role_least_privilege"></a> [task\_execution\_role\_least\_privilege](#input\_task\_execution\_role\_least\_privilege) | n/a | <pre>object({<br/>    ecr_registry_arns          = optional(list(string), [])<br/>    secretsmanager_secret_arns = optional(list(string), [])<br/>    ssm_parameter_arns         = optional(list(string), [])<br/>    kms_key_arns               = optional(list(string), [])<br/>    route53_hosted_zone_arns   = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "ecr_registry_arns": [],<br/>  "kms_key_arns": [],<br/>  "route53_hosted_zone_arns": [],<br/>  "secretsmanager_secret_arns": [],<br/>  "ssm_parameter_arns": []<br/>}</pre> | no |
| <a name="input_task_execution_role_managed_policy_arns"></a> [task\_execution\_role\_managed\_policy\_arns](#input\_task\_execution\_role\_managed\_policy\_arns) | Extra managed policies for the shared task execution role, on top of AmazonECSTaskExecutionRolePolicy. | `list(string)` | `[]` | no |
| <a name="input_task_execution_role_permission_boundary_arn"></a> [task\_execution\_role\_permission\_boundary\_arn](#input\_task\_execution\_role\_permission\_boundary\_arn) | n/a | `string` | `null` | no |
| <a name="input_task_sg_egress_rules"></a> [task\_sg\_egress\_rules](#input\_task\_sg\_egress\_rules) | Declarative egress rules for the cluster's task SG (<name>-tasks) - same shape and semantics as task\_sg\_ingress\_rules (modelled on terraform-aws-eks node-group security\_group\_egress\_rules). The task SG already has an allow-all egress rule; use this to add specific egress entries anyway, e.g. for auditing. | <pre>map(object({<br/>    name                         = optional(string)<br/>    cidr_ipv4                    = optional(string)<br/>    cidr_ipv6                    = optional(string)<br/>    description                  = optional(string)<br/>    from_port                    = optional(string)<br/>    ip_protocol                  = optional(string)<br/>    prefix_list_id               = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>    self                         = optional(bool)<br/>    tags                         = optional(map(string), {})<br/>    to_port                      = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_task_sg_ingress_rules"></a> [task\_sg\_ingress\_rules](#input\_task\_sg\_ingress\_rules) | Declarative ingress rules for the cluster's task SG (<name>-tasks) - the SG is attached to every node group instance and awsvpc task ENI, so rules here open ports at the node level (bridge-mode host ports) and the task level alike. Modelled on terraform-aws-eks node-group security\_group\_ingress\_rules: the map key is the rule's stable identity, from\_port/to\_port are strings, omit to\_port for a single port, self = true references the task SG itself. | <pre>map(object({<br/>    name                         = optional(string)<br/>    cidr_ipv4                    = optional(string)<br/>    cidr_ipv6                    = optional(string)<br/>    description                  = optional(string)<br/>    from_port                    = optional(string)<br/>    ip_protocol                  = optional(string)<br/>    prefix_list_id               = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>    self                         = optional(bool)<br/>    tags                         = optional(map(string), {})<br/>    to_port                      = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tg_health_check_port"></a> [tg\_health\_check\_port](#input\_tg\_health\_check\_port) | ALB target-group health-check port, opened from alb\_security\_group\_id in addition to the ephemeral range, if different from "traffic-port". | `string` | `null` | no |
| <a name="input_use_tagger"></a> [use\_tagger](#input\_use\_tagger) | Compute and apply standardized tags via terraform-null-tagger. When false, use var.tags as-is instead. | `bool` | `true` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC the cluster's SG and node groups live in. | `string` | n/a | yes |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addons"></a> [addons](#output\_addons) | Add-on outputs per enabled preset (null when cluster\_addons is unset). |
| <a name="output_capacity_provider_arns"></a> [capacity\_provider\_arns](#output\_capacity\_provider\_arns) | ARNs of the EC2 capacity providers, keyed by node group name. |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | CloudWatch log group used for ECS exec logging. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ECS cluster ARN. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | ECS cluster ID (ARN). |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | ECS cluster name. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Cluster security group ID (tasks and node host ports join it). |
| <a name="output_ecs_infrastructure_role_arn"></a> [ecs\_infrastructure\_role\_arn](#output\_ecs\_infrastructure\_role\_arn) | ARN of the ECS infrastructure role (for EBS task volume management). Null when create\_ecs\_infrastructure\_role is false and no infrastructure\_role\_arn override is provided. |
| <a name="output_exec_kms_key_id"></a> [exec\_kms\_key\_id](#output\_exec\_kms\_key\_id) | KMS key ID used to encrypt ECS exec logging destinations, if enabled. |
| <a name="output_exec_s3_bucket_arn"></a> [exec\_s3\_bucket\_arn](#output\_exec\_s3\_bucket\_arn) | ARN of the S3 bucket used for ECS exec logging, if enabled. |
| <a name="output_exec_s3_bucket_name"></a> [exec\_s3\_bucket\_name](#output\_exec\_s3\_bucket\_name) | S3 bucket used for ECS exec logging, if enabled. |
| <a name="output_node_groups"></a> [node\_groups](#output\_node\_groups) | Node group outputs (ASG ARN/name), keyed by node group name. |
| <a name="output_services"></a> [services](#output\_services) | Service outputs (name, task definition ARN/family), keyed by service name. |
| <a name="output_topology_fragment"></a> [topology\_fragment](#output\_topology\_fragment) | Network topology fragment for composition with sibling modules via provider::netutils::mermaid\_merge(). See terraform-provider-netutils's docs/topology-fragment-spec.md. The ECS cluster itself is deliberately excluded - see node\_groups.tf. |


<!-- references -->

[repo_link]: https://github.com/rafalmasiarek/terraform-aws-ecs
