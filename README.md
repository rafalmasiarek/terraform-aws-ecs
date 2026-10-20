# Terraform AWS ECS

ECS cluster module: cluster, capacity providers, EC2 node groups, services, composable IAM, cluster security group, and optional infrastructure add-ons.

## Requirements

| Provider | Version |
|---|---|
| hashicorp/aws | >= 6.0 |
| rafalmasiarek/tagger (module) | >= 0.7.0 |

## Inputs (key variables)

| Variable | Description |
|---|---|
| `name` | Cluster name prefix. |
| `vpc_id` | VPC to create the cluster in. |
| `node_groups` | Map of EC2 node group configs (ASG + launch template). See `modules/node-group/`. |
| `fargate_capacity_providers` | List of Fargate capacity provider names to register. |
| `services` | Map of ECS service configs. See `modules/service/`. |
| `task_sg_ingress_rules` / `task_sg_egress_rules` | Custom rules on the cluster security group. |
| `cluster_addons` | Optional map of infrastructure add-on presets. See below. |
| `create_ecs_infrastructure_role` | Create the ECS infrastructure IAM role (EBS task volume management, default false). |
| `infrastructure_role_arn` | Use an existing infrastructure role instead of creating one (mutually exclusive with above). |
| `create_task_execution_role` | Create a shared task execution role. |
| `exec_command_s3` | Enable ECS Exec session logging to S3. |
| `use_tagger` | Enable standardized tagging via terraform-null-tagger (default true). |
| `tagger_context` | Shared context from the root stack's base tagger call. |

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
    traefik       = { port = 8080 }
  }
}
```

Output: `addons` — per-preset outputs (service ARN, task definition family, LB DNS where applicable). Null when `cluster_addons` is unset.

## Outputs

| Output | Description |
|---|---|
| `cluster_id` / `cluster_arn` / `cluster_name` | Cluster identity. |
| `cluster_security_group_id` | Default cluster SG (auto-opens service container ports). |
| `capacity_provider_arns` | Registered capacity provider ARNs. |
| `node_groups` | Per-node-group ASG ARN/name. |
| `services` | Per-service task definition ARN/family. |
| `cloudwatch_log_group_name` | ECS Exec CloudWatch log group, when enabled. |
| `exec_s3_bucket_name` / `exec_s3_bucket_arn` | ECS Exec S3 logging bucket, when enabled. |
| `exec_kms_key_id` | KMS key used for ECS Exec logging. |
| `ecs_infrastructure_role_arn` | ECS infrastructure IAM role ARN (EBS task volume management). |
| `addons` | Per-preset add-on outputs (null if disabled). |

## Tagger integration

All resources are tagged via terraform-null-tagger when `use_tagger = true`. Each sub-module (`node-group`, `service`, `iam-role`, `addons`) copies the same `tagger.tf` wiring and computes its own tags from the shared `tagger_context`:

- `container.cluster` — cluster name
- `container.task_family` — per service
- `container.node_group` — per node group
- `block_storage` — EBS volumes (type, file_system_type; size/iops excluded due to live resize drift)
- `compute` — node group instances (instance_type, os, architecture)
- `origin_module` — sub-module path (e.g. `github.com/rafalmasiarek/terraform-aws-ecs//modules/service`)
