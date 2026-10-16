# Falco

Runtime security monitoring (CNCF Falco) as an EC2 DAEMON service — one task per node, bridge networking. Watches syscalls for anomalous behavior and alerts.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable. |
| `image` | `falcosecurity/falco:latest` | Image override. |
| `task_cpu` / `task_memory` | 512/512 | Task sizing. |
| `driver_mode` | `"ebpf"` | `"ebpf"` or `"kmod"` (validated). eBPF needs no kernel modules; kmod needs the matching falco kernel module on the host. |
| `environment` / `docker_labels` / `command` / `extra_args` | – | Standard container overrides. |
| `extra_task_policies` | `{}` | Extra task-role policies. |
| `tags` | `{}` | Extra tags. |

The task bind-mounts the host root, `/var`, `/dev`, `/proc`, `/sys` (Falco needs host access to observe processes).

## Basic

```hcl
cluster_addons = {
  falco = {}
}
```

## Expert

```hcl
falco = {
  driver_mode = "ebpf"
  extra_args  = ["-o", "json_output=true"]
  environment = { FALCO_RULES_FILE = "/etc/falco/custom_rules.yaml" }
}
```
