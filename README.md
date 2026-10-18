# Terraform AWS ECS

ECS cluster module: cluster, capacity providers, node groups (EC2), services, and optional infrastructure add-ons.

## Requirements

| Provider | Version |
|---|---|
| hashicorp/aws | >= 6.0 |
| rafalmasiarek/tagger (module) | >= 0.7.0 |

The `origin_module` tagger variable requires null-tagger >= 0.7.0. Until that version is published to the registry, `terraform validate` will report an "attribute not expected" error on `origin_module` — this is expected and resolves automatically after publish.

## Inputs (key variables)

| Variable | Description |
|---|---|
| `name` | Cluster name prefix. |
| `vpc_id` | VPC to create the cluster in. |
| `subnet_ids` | Subnets for cluster ENIs / load balancers. |
| `node_groups` | Map of EC2 node group configs (ASG + launch template). See `modules/node-group/`. |
| `fargate_capacity_providers` | List of Fargate capacity provider names to register. |
| `services` | Map of ECS service configs. See `modules/service/`. |
| `cluster_addons` | Optional map of infrastructure add-on presets. See below. |
| `create_infrastructure_role` | Create a dedicated IAM role for the cluster (default true). |
| `infrastructure_role_arn` | Use an existing role instead (mutually exclusive with above). |
| `use_tagger` | Enable standardized tagging via terraform-null-tagger (default true). |
| `tagger_context` | Shared context from the root stack's base tagger call. |

## Cluster add-ons

`cluster_addons` enables pre-built infrastructure services on the cluster:

| Preset | What it runs |
|---|---|
| `traefik` | Traefik ingress controller (load balancer type service). |
| `opentelemetry` | OTel Collector (host network, EC2). |
| `cloudwatch_agent` | CloudWatch Agent (EC2, privileged). |
| `fluent_bit` | Fluent Bit log router (EC2, privileged). |
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
| `cluster_id` / `cluster_name` | Cluster identity. |
| `cluster_security_group_id` | Default cluster SG (auto-opens service container ports). |
| `capacity_provider_arns` | Registered capacity provider ARNs. |
| `node_groups` | Per-node-group ASG ARN/name. |
| `services` | Per-service task definition ARN/family. |
| `infrastructure_role_arn` | Cluster IAM role ARN. |
| `addons` | Per-preset add-on outputs (null if disabled). |

## Tagger integration

All resources are tagged via terraform-null-tagger when `use_tagger = true`:

- `container.cluster` — cluster name
- `container.task_family` — per service
- `container.node_group` — per node group
- `block_storage` — EBS volumes (type, file_system_type; size/iops excluded due to live resize drift)
- `compute` — node group instances (instance_type, os, architecture)
- `origin_module` — sub-module path (e.g. `github.com/rafalmasiarek/terraform-aws-ecs//modules/service`)
