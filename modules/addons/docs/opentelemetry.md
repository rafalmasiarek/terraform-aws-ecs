# OpenTelemetry Collector

Distributed tracing / metrics collector (OTel contrib) running as a Fargate service. Receives OTLP on 4317/4318 and exports to CloudWatch, X-Ray and/or an external OTLP endpoint.

## Parameters

| Key | Default | Effect |
|---|---|---|
| `enabled` | `true` | Set false to disable. |
| `image` | `public.ecr.aws/aws-observability/aws-otel-collector:latest` | Image override. |
| `task_cpu` / `task_memory` | 512/512 | Task sizing. |
| `desired_count` | `1` | Replicas. |
| `launch_type` | `"FARGATE"` | Launch type. |
| `capacity_provider_strategy` | `[]` | EC2 capacity instead of Fargate. |
| `subnets` | all VPC subnets | Task ENI placement. |
| `security_groups` | `[]` | Extra SGs. |
| `exporters.aws_cloudwatch.enabled` | `true` | Export metrics to CloudWatch Logs. |
| `exporters.aws_cloudwatch.namespace` | cluster name | Metric namespace. |
| `exporters.aws_xray.enabled` | `false` | Export traces to X-Ray. |
| `exporters.otlp.enabled` | `false` | Forward to an external OTLP endpoint. |
| `exporters.otlp.endpoint` | – | Required when enabled (validated). |
| `exporters.otlp.insecure` | `false` | Plaintext OTLP. |
| `discovery.enabled` | `false` | EC2 scraper receiver (host metrics from the VPC). |
| `config_override` | – | Full collector YAML; replaces the generated config. |
| `environment` / `docker_labels` / `command` / `extra_args` | – | Standard container overrides. |
| `extra_task_policies` | `{}` | Extra task-role policies. |
| `tags` | `{}` | Extra tags. |

## Basic

```hcl
cluster_addons = {
  opentelemetry = {}
}
```

One collector, OTLP in, CloudWatch out.

## Expert

```hcl
opentelemetry = {
  desired_count = 2
  exporters = {
    aws_cloudwatch = { enabled = true, namespace = "prod" }
    aws_xray       = { enabled = true }
    otlp           = { enabled = true, endpoint = "otlp-gateway.internal:4317" }
  }
  discovery = { enabled = true }
}
```
