# cAdvisor

Container metrics (cAdvisor) as an EC2 DAEMON service — one task per node, bridge networking, host port 8080. Per-container CPU/memory/network/filesystem usage.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable. |
| `image` | `ghcr.io/google/cadvisor:latest` | Image override. |
| `task_cpu` / `task_memory` | 128/128 | Task sizing. |
| `port` | `8080` | Host/container port. |
| `environment` / `docker_labels` / `command` / `extra_args` | – | Standard container overrides. |
| `extra_task_policies` | `{}` | Extra task-role policies. |
| `tags` | `{}` | Extra tags. |

The task bind-mounts the host root and runs with `--rootfs=/host`.

## Basic

```hcl
cluster_addons = {
  cadvisor = {}
}
```

## Expert

```hcl
cadvisor = {
  port       = 8081
  extra_args = ["--housekeeping_interval=30s"]
}
```
