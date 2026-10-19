# ECS Cluster Add-ons

Infrastructure add-ons for the cluster, enabled through a single `cluster_addons` map. Each preset is optional and independent; omit the whole variable (or pass `{}`) to disable everything.

```hcl
module "ecs" {
  source = "rafalmasiarek/terraform-aws-ecs"

  name   = "prod"
  vpc_id = aws_vpc.this.id

  node_groups = { … }
  services    = { … }

  cluster_addons = {
    traefik           = {}
    opentelemetry     = {}
    # node_exporter   = {}   # EC2 only
    # cadvisor        = {}   # EC2 only
    # falco           = {}   # EC2 only
    # cloudwatch_agent = {}
    # blackbox_exporter = {}
  }
}
```

## Presets

| Preset | Model | What it does | Docs |
|---|---|---|---|
| `traefik` | EC2 → DAEMON bridge (host ports 80/443); Fargate → REPLICA awsvpc | Reverse proxy / ingress. Create mode builds an internal ALB by default; NLB, routes, ACME/manual TLS supported. | [traefik.md](../modules/addons/docs/traefik.md) |
| `opentelemetry` | Fargate REPLICA | OTel collector: OTLP in (4317/4318), CloudWatch/X-Ray/OTLP out. | [opentelemetry.md](../modules/addons/docs/opentelemetry.md) |
| `cloudwatch_agent` | Fargate REPLICA | CloudWatch agent — host/container metrics. | [cloudwatch_agent.md](../modules/addons/docs/cloudwatch_agent.md) |
| `node_exporter` | EC2 DAEMON (bridge, host port 9100) | Prometheus node exporter per node. | [node_exporter.md](../modules/addons/docs/node_exporter.md) |
| `cadvisor` | EC2 DAEMON (bridge, host port 8080) | Container metrics per node. | [cadvisor.md](../modules/addons/docs/cadvisor.md) |
| `falco` | EC2 DAEMON (bridge) | Runtime security monitoring (eBPF/kmod). | [falco.md](../modules/addons/docs/falco.md) |
| `blackbox_exporter` | Fargate REPLICA (port 9115) | Synthetic HTTP/TCP probes. | [blackbox_exporter.md](../modules/addons/docs/blackbox_exporter.md) |

## Conventions

- **Naming**: services `<cluster>-addon-<key>`, IAM roles `<cluster>-addon-<key>-task` / `-execution`, log groups `/aws/ecs/<cluster>/addons/<key>`, SSM params `/ecs/<cluster>/addon-…`.
- **Images** float on `:latest` by default; pin per preset with `image` (full reference) for production.
- **IAM**: every preset gets its own task + execution role (scoped policies); extend with `extra_task_policies`.
- **Networking**: awsvpc presets default to every available subnet of the VPC; the cluster SG is always attached. EC2 daemon presets use bridge networking and bind host ports on the nodes.
- **Requirements**: any enabled preset needs the cluster SG (always present); presets that create LBs or need VPC-scoped resources need `vpc_id` (checked at plan time).

## Costs & destruction

- Fargate presets run continuously (per-vCPU-second); keep `desired_count` minimal.
- EC2 daemon presets cost nothing extra beyond the nodes themselves.
- Destroying the module removes all addon services, task definitions, roles, LBs and SSM parameters. The EFS/EBS volumes referenced by `tls.*.storage` are **not** deleted (they are caller-owned inputs).
