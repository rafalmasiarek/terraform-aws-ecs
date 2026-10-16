# Node Exporter

Prometheus node exporter as an EC2 DAEMON service (one task per node, bridge networking, host port 9100). Exposes host CPU/memory/disk/network/filesystem metrics.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable. |
| `image` | `prom/node-exporter:latest` | Image override. |
| `task_cpu` / `task_memory` | 128/128 | Task sizing. |
| `port` | `9100` | Host/container port. |
| `environment` / `docker_labels` / `command` / `extra_args` | – | Standard container overrides. |
| `extra_task_policies` | `{}` | Extra task-role policies. |
| `tags` | `{}` | Extra tags. |

The task bind-mounts the host root (`/`, `/var`, `/dev`, `/proc`, `/sys`) and runs with `--path.rootfs=/host`.

## Basic

```hcl
cluster_addons = {
  node_exporter = {}
}
```

## Expert

```hcl
node_exporter = {
  port     = 9101
  extra_args = ["--collector.textfile.directory=/host/etc/metrics"]
}
```
