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
