data "aws_region" "current" {
}

# Default image references. The registries/repos are verified against vendor
# documentation; the tags intentionally float on :latest so upstream point
# releases do not require a module release. Pin per preset with `image`
# (full reference: registry/repo:version-or-digest) for production use.
locals {
  default_images = {
    traefik          = "traefik:latest"
    opentelemetry    = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
    cloudwatch_agent = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest"
    # -debug variant: the standard image is distroless (no /bin/sh), but the
    # container bootstrap needs a shell to materialize the config secret.
    fluent_bit        = "fluent/fluent-bit:latest-debug"
    node_exporter     = "prom/node-exporter:latest"
    cadvisor          = "ghcr.io/google/cadvisor:latest"
    falco             = "falcosecurity/falco:latest"
    blackbox_exporter = "prom/blackbox-exporter:latest"
  }

  addon_image = { for k, v in local.default_images : k => coalesce(
    try(var.cluster_addons[k].image, null),
    local.default_images[k],
  ) }
}
