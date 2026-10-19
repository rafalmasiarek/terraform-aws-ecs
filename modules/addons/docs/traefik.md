# Traefik

Reverse proxy / ingress for the cluster. `traefik = {}` works out of the box: on EC2 capacity it runs as a DAEMON bridge service (one proxy per node, host ports 80/443, no task ENI) and creates an internal ALB; on Fargate it is a replicated awsvpc service.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable the preset. |
| `image` | `traefik:latest` | Full image reference override. |
| `task_cpu` / `task_memory` | EC2: 512/256, Fargate: 256/512 | Task sizing. Must be valid for the compatibility list. |
| `launch_type` | `"FARGATE"` | `"EC2"` selects the daemon model (see below). |
| `scheduling_strategy` | `"DAEMON"` | With EC2 launch type/capacity providers: `DAEMON` (default, one task per node, bridge networking) or `REPLICA` (replicated awsvpc). Ignored on Fargate. |
| `desired_count` | `2` | REPLICA mode only. |
| `capacity_provider_strategy` | `[]` | Non-empty strategy forces EC2 compat regardless of launch_type. |
| `subnets` | all VPC subnets | awsvpc tasks only. |
| `security_groups` | `[]` | Extra SGs on the task ENIs (cluster SG always added). |
| `routes` | `[]` | Declarative routers, see below. |
| `environment` | `{}` | Extra container env vars. |
| `docker_labels` | `{}` | ECS provider labels on the container. |
| `extra_args` | `[]` | Extra traefik CLI flags. |
| `extra_task_policies` | `{}` | `managed_policy_arns` + `inline_policies` on the task role. |
| `force_new_deployment` | `false` | Set once when migrating between deployment models (REPLICA ↔ DAEMON); the provider requires it for capacity_provider_strategy updates. |
| `tags` | `{}` | Extra tags on this preset's resources. |

### `ingress`

Create mode is the default — an omitted or empty block still builds the load balancer.

| Key | Default | Effect |
|---|---|---|
| `create_load_balancer` | `true` | `false` = existing mode: the module only registers the service on your target group(s); LB, listeners and SG rules are yours. |
| `target_group_arn` | – | Existing mode: your TG for port 80 (required). |
| `target_group_arn_443` | – | Existing mode + 443 entrypoint: separate TG (ECS rejects duplicate TGs in one service). |
| `load_balancer_type` | `"alb"` | `"nlb"` = L4 TCP passthrough (an NLB cannot terminate TLS; pair with `tls.managed_by = "traefik"` or manual certs). |
| `internal` | `true` | Internal ALB/NLB (VPC-only traffic) vs internet-facing. |
| `tls_enabled` | `false` | ALB create mode: terminate TLS on the LB (443 listener), requires `certificate_arn`. Existing mode: expose the container's 443 entrypoint so your own TLS listener has a backend. |
| `certificate_arn` | – | ACM certificate for `tls_enabled`. |
| `subnets` | all VPC subnets | Where the LB lives. |
| `security_groups` | `[]` | Extra SGs on the LB. |

### `tls`

| Key | Default | Effect |
|---|---|---|
| `managed_by` | `"lb"` | `"lb"` = the ALB terminates TLS (or plain HTTP); `"traefik"` = ACME Let's Encrypt inside traefik; `"manual"` = user-provided certificates. |
| `acme.email` | – | Required for `managed_by = "traefik"`. |
| `acme.dns_provider` | `"route53"` | Any traefik DNS provider (`cloudflare`, `digitalocean`, …). DNS-01 challenge records are created/removed by traefik itself — the task role gets Route53 perms automatically. |
| `acme.storage` | – | Persistent cert store (optional; default: task-ephemeral `/data`). Shape below. |
| `certificates_directory` | `/etc/traefik/certs` | Manual TLS: directory scanned for `*.crt`/`*.key` pairs (SNI-based, scales to many domains). |
| `storage` | – | Manual TLS: volume mounted at `certificates_directory` (omit if certs are baked into the image). Same shape as `acme.storage`. |

Storage shape (exactly one identifier, matching `type`):

```hcl
storage = {
  type          = "efs"   # or "ebs"
  filesystem_id = "fs-…"  # EFS — or volume_id for EBS — or arn
}
```

### `routes`

Each entry becomes a traefik router (file provider, hot-reloaded). `service` is the **ECS service name** hosting the backend — the ECS provider exposes it as a traefik service of the same name (that service must not carry its own `load_balancer` arg; routing is label-based).

```hcl
routes = [
  { name = "app", rule = "Host(`app.example.com`)", service = "my-cluster-app" },
  { name = "wildcard", rule = "Host(`*.example.com`)", service = "my-cluster-api", entrypoints = ["web"] },
]
```

Wildcards work natively. The routes document is delivered through an SSM SecureString secret (`TRAEFIK_ROUTES`) written to `/etc/traefik/dynamic/routes.yml` at task start.

## Basic

```hcl
cluster_addons = {
  traefik = {}
}
```

EC2 cluster → daemon on every node + internal ALB. Fargate cluster → 2 replicas + internal ALB. Nothing else needed.

## Expert

```hcl
cluster_addons = {
  traefik = {
    ingress = {
      internal           = false        # internet-facing
      load_balancer_type = "alb"
      tls_enabled        = true
      certificate_arn    = aws_acm_certificate.app.arn
    }

    routes = [
      { name = "app", rule = "Host(`app.example.com`)", service = "prod-app" },
      { name = "api", rule = "Host(`api.example.com`)", service = "prod-api" },
    ]

    environment = { TRAEFIK_LOG_LEVEL = "DEBUG" }
  }
}
```

ACME (Let's Encrypt, DNS-01 via Route53, persistent store on EFS):

```hcl
tls = {
  managed_by = "traefik"
  acme = {
    email        = "ops@example.com"
    dns_provider = "route53"
    storage      = { type = "efs", filesystem_id = "fs-…" }
  }
}
```

Manual certificates (many domains, SNI):

```hcl
tls = {
  managed_by             = "manual"
  certificates_directory = "/etc/traefik/certs"
  storage                = { type = "efs", filesystem_id = "fs-…" }
}
# Upload <host>.crt / <host>.key pairs to that EFS path.
```

Existing load balancer (you own the ALB, the module wires the TG):

```hcl
ingress = {
  create_load_balancer = false
  target_group_arn     = aws_lb_target_group.yours.arn
  # tls_enabled = true + target_group_arn_443 = … when your LB has a TLS listener
}
```

## Notes

- Target group target type follows the deployment model: `instance` for daemon/bridge tasks, `ip` for awsvpc (ECS rejects ip-type TGs registered with bridge tasks).
- Port mappings always set `hostPort = containerPort` (Fargate requires the match; daemon binds the node port).
- Static config is passed as CLI flags; the container starts through a `/bin/sh -c` bootstrap that materializes the routes file first (the legacy `container_definitions` JSON drops `secrets[].file`).
- Migrating an existing service between REPLICA and DAEMON requires `force_new_deployment = true` for exactly one apply.
