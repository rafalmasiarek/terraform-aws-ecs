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
| `routes` | `[]` | Declarative HTTP routers, see below. |
| `tcp_routes` | `[]` | Declarative TCP routers (non-HTTP), see below. |
| `udp_routes` | `[]` | Declarative UDP routers, see below. |
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
| `cross_zone_load_balancing` | `true` | `load_balancer_type = "nlb"` only (ALBs are always cross-zone, not configurable). Keep `true` unless you specifically want to limit a target to its own AZ - otherwise a single-task service only reachable from one of the NLB's several AZ endpoints looks intermittently unreachable from the others. |
| `tls_enabled` | `false` | ALB create mode: terminate TLS on the LB (443 listener), requires `certificate_arn`. Existing mode: expose the container's 443 entrypoint so your own TLS listener has a backend. |
| `certificate_arn` | – | ACM certificate for `tls_enabled`. |
| `subnets` | all VPC subnets | Where the LB lives. |
| `security_groups` | `[]` | Extra SGs on the LB. |
| `listeners` | `{http={port=80}, https={port=443}}` | Map, create mode only. Each entry: `port` (LB-facing), `container_port` (traefik entrypoint, default = `port` - any value works, not just 80/443), `protocol`, `certificate_arn`, `redirect_to`, and optional `entrypoint_name`. Ports 80/443 always get the fixed names `web`/`websecure`; any other `container_port` needs `entrypoint_name` to be referenceable from a route's `entrypoints` (falls back to `ep<port>` otherwise). |

### `tls`

| Key | Default | Effect |
|---|---|---|
| `managed_by` | `"lb"` | `"lb"` = the ALB terminates TLS (or plain HTTP); `"traefik"` = ACME Let's Encrypt inside traefik; `"manual"` = user-provided certificates. |
| `redirect_to_https` | `true` | Redirect all `web` (80) traffic to `websecure` (443), via a file-provider router rather than a plain entrypoint redirect - so it's safe to combine with any `acme.challenge_type` (the router excludes `/.well-known/acme-challenge/` and traefik's own `/ping`, instead of redirecting literally everything on `web` before any router gets a say - see [traefik#7883](https://github.com/traefik/traefik/issues/7883)). Set `false` only if you genuinely want plain HTTP served as-is. |
| `acme.email` | – | Required for `managed_by = "traefik"`. |
| `acme.challenge_type` | `"dns"` | `"dns"` = DNS-01 (works for wildcards; needs a provider, see below). `"http"` = HTTP-01 (no DNS provider/credentials needed; single hostnames only). `"tls"` = TLS-ALPN-01 (no DNS provider, no port-80 dependency - the challenge happens inside the TLS handshake on 443 itself). All three work regardless of `redirect_to_https`. |
| `acme.dns_provider` | `"route53"` | DNS-01 only. Any traefik DNS provider (`cloudflare`, `digitalocean`, …). For `route53`, the task role gets Route53 perms automatically; any other provider needs its own credentials passed via `environment` (e.g. Cloudflare: `CF_DNS_API_TOKEN`, a scoped `Zone:DNS:Edit` token - see [lego's cloudflare docs](https://go-acme.github.io/lego/dns/cloudflare/)). |
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

### Naming the backend `service`

Every route (`routes`, `tcp_routes`, `udp_routes`) targets a backend by name - write the bare name, the module appends `@ecs` for you (traefik's ECS provider; without it, traefik looks for a same-named service on the *file* provider instead, which doesn't exist, and fails with `the service "..." does not exist`). Two conventions, depending on the backend container's own port count:

- **Single port on the container**: the name is `service-<ecs-service-name>-<container-name>` — the ECS provider's own naming, *not* the bare ECS service name.
- **More than one `portMappings` entry on the container** (HTTP + HTTPS + a raw TCP port, say): the container needs a `dockerLabels` entry per port to disambiguate, which the root `services` variable generates automatically for any `portMappings` entry (see its description in `variables.tf`). Give the port a `name` (ECS's own Service Connect field) and that name becomes the traefik service name **verbatim** - write the same word in the route's `service`, nothing to reconstruct. Only ports left without a `name` fall back to the auto-generated `<service-key>-<container-name>-<index>` form (unique by construction, but you have to know the formula to reference it).

This addon's ECS provider always runs with `exposedByDefault=false` - a container isn't discoverable at all (the router fails with `the service "..." does not exist`, a 404 from the client's point of view) unless it carries a `traefik.enable=true` docker label. The root `services` variable adds that label automatically to whichever container a route's `service` string actually resolves to (by the two conventions above) - you only write the name once, in the route, same as always. There's nothing left to do here; this note exists because an earlier version of this module required adding the label by hand, which was easy to forget.

```hcl
# services["web"].container_definitions[0] = { name = "web", portMappings = [{ containerPort = 8080 }] }
# -> single port, auto-discovered: service = "service-<cluster>-web-web"

# services["mail"].container_definitions[0] = {
#   name = "app"
#   portMappings = [
#     { containerPort = null, protocol = "tcp", name = "imap" },  # -> service = "imap"
#     { containerPort = null, protocol = "tcp" },                  # unnamed -> service = "mail-app-1"
#   ]
# }
```

Named ports are the recommended path - pick a unique name per port and use it as-is; the fallback exists so an unnamed port is still referenceable, not as something to compute on purpose.

### `routes`

Each entry becomes an HTTP router (file provider, hot-reloaded).

```hcl
routes = [
  { name = "app", rule = "Host(`app.example.com`)", service = "service-prod-app-app" },
  { name = "wildcard", rule = "Host(`*.example.com`)", service = "http", entrypoints = ["web", "websecure"] },
]
```

Wildcards work natively. `entrypoints` defaults to `["web"]`; add `"websecure"` to also serve the same backend over TLS (TLS behavior itself is controlled by `tls`, above — the backend always receives plain HTTP regardless of which entrypoint the client used).

### `tcp_routes`

For raw TCP backends (anything that isn't HTTP - IMAP, a database protocol, …). Each entry gets its **own** traefik entrypoint, one-to-one with `port` - there's no shared `entrypoints` map, the router's name *is* its entrypoint's name. `rule` defaults to `HostSNI(`*`)` (match everything; TCP routers can match on SNI for TLS passthrough, but most raw-TCP use cases don't need that).

```hcl
tcp_routes = [
  { name = "imap", port = 143, service = "imap" },
]
```

### `udp_routes`

Same one-entrypoint-per-route model as `tcp_routes`, but UDP routers have no rule concept at all - traffic on the entrypoint goes straight to the service.

```hcl
udp_routes = [
  { name = "dns", port = 53, service = "dns" },
]
```

Every `tcp_routes`/`udp_routes` port is automatically added to the traefik container's own `portMappings` and to its CLI flags (`--entrypoints.<name>.address=:<port>/tcp|udp`) - you only need to open it on a security group (`task_sg_ingress_rules` at the root, same as port 80/443).

The combined routes document (http + tcp + udp sections) is delivered through an SSM SecureString secret (`TRAEFIK_ROUTES`) written to `/etc/traefik/dynamic/routes.yml` at task start.

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
      { name = "app", rule = "Host(`app.example.com`)", service = "service-prod-app-app" },
      { name = "api", rule = "Host(`api.example.com`)", service = "service-prod-api-api" },
    ]

    tcp_routes = [
      { name = "imap", port = 143, service = "imap" },
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
- A backend container with a `portMappings` entry left at `containerPort = null` (awsvpc only) gets a stable, auto-assigned port and a `PORT_<index>` env var so its own startup command can bind to it - see `services` in the root `variables.tf`.
- Traefik's own `/ping` is always enabled and routed on every entrypoint that has a target group - ALB create-mode health checks use it (`/ping`, not `/`, which could collide with a real route).
