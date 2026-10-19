# Blackbox Exporter

Prometheus blackbox exporter (Fargate service) for synthetic probing — HTTP/TCP/ICMP checks against your endpoints, scraped on port 9115.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable. |
| `image` | `prom/blackbox-exporter:latest` | Image override. |
| `task_cpu` / `task_memory` | 256/256 | Task sizing. |
| `port` | `9115` | Host/container port. |
| `config` | generated | Blackbox YAML; null = default (`http_2xx` module). |
| `config_override` | – | Wins over `config`. |
| `environment` / `docker_labels` / `command` / `extra_args` | – | Standard container overrides. |
| `extra_task_policies` | `{}` | Extra task-role policies. |
| `tags` | `{}` | Extra tags. |

## Basic

```hcl
cluster_addons = {
  blackbox_exporter = {}
}
```

## Expert

```hcl
blackbox_exporter = {
  config = yamlencode({
    modules = {
      http_2xx = {
        prober = "http"
        http   = { valid_status_codes = [200, 204], method = "GET" }
      }
      tcp_connect = {
        prober = "tcp"
      }
    }
  })
}
```
