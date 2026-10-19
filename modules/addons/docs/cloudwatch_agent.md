# CloudWatch Agent

AWS CloudWatch agent as a Fargate service — host and container metrics into CloudWatch.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable. |
| `image` | `public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest` | Image override. |
| `task_cpu` / `task_memory` | 128/64 | Task sizing. |
| `config` | generated | Agent JSON config; null = default (cpu/mem/disk/net, region auto). |
| `environment` / `docker_labels` / `command` / `extra_args` | – | Standard container overrides. |
| `extra_task_policies` | `{}` | Extra task-role policies. |
| `tags` | `{}` | Extra tags. |

## Basic

```hcl
cluster_addons = {
  cloudwatch_agent = {}
}
```

## Expert

```hcl
cloudwatch_agent = {
  config = jsonencode({
    agent   = { region = "eu-central-1" }
    metrics = {
      metrics_collected = { cpu = {}, mem = {}, disk = {}, net = {}, ecs = { stats = ["container", "cpu", "mem"] } }
      force_flush_interval = 30
    }
  })
}
```
