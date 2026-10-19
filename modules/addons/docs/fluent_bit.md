# Fluent Bit

Log shipper (Fargate service) tailing container logs and shipping them to CloudWatch Logs. The default image is `fluent/fluent-bit:latest-debug` — the standard image is distroless (no `/bin/sh`), but the container bootstrap needs a shell to materialize the config from its secret.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable. |
| `image` | `fluent/fluent-bit:latest-debug` | Image override (keep a `-debug`/shell-capable variant). |
| `task_cpu` / `task_memory` | 256/256 | Task sizing. |
| `config` | generated | Fluent Bit conf; null = generated (tail `/var/log/containers/*.log` → CloudWatch). |
| `config_override` | – | Wins over `config`. |
| `environment` / `docker_labels` / `command` / `extra_args` | – | Standard container overrides. |
| `extra_task_policies` | `{}` | Extra task-role policies. |
| `tags` | `{}` | Extra tags. |

## Basic

```hcl
cluster_addons = {
  fluent_bit = {}
}
```

## Expert

```hcl
fluent_bit = {
  config = <<-CONF
    [SERVICE]
        Flush 5
        Daemon off

    [INPUT]
        Name  tail
        Path  /var/log/containers/*.log
        Parser docker
        Tag   ecs.*

    [OUTPUT]
        Name              cloudwatch
        Match             ecs.*
        Region            eu-central-1
        Log_Group_Name    /aws/ecs/my-cluster/addons/fluent-bit
        Log_Stream_Name   {stream_name}
        Auto_Create_Group true
  CONF
}
```
